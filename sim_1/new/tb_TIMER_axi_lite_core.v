`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/17/2026 10:58:12 PM
// Design Name: 
// Module Name: tb_TIMER_axi_lite_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module tb_TIMER_axi_lite_core();

    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CYCLE_CLOCK = 2;
    
    parameter [ADDR_WIDTH-1:0] ADDR_REG0 = 32'h0200_4000; // Đọc phần cao [49:32]
    parameter [ADDR_WIDTH-1:0] ADDR_REG_LOW = 32'h0200_4004; // Đọc phần thấp [31:0]

    // Signals
    reg clk;
    reg resetn;

    // AXI-Lite Write Channels
    reg [ADDR_WIDTH-1:0] i_axi_awaddr;
    reg                  i_axi_awvalid;
    wire                 o_axi_awready;
    reg [2:0]            i_axi_awprot;

    reg [DATA_WIDTH-1:0] i_axi_wdata;
    reg [3:0]            i_axi_wstrb;
    reg                  i_axi_wvalid;
    wire                 o_axi_wready;

    wire [1:0]           o_axi_bresp;
    wire                 o_axi_bvalid;
    reg                  i_axi_bready;

    // AXI-Lite Read Channels
    reg [ADDR_WIDTH-1:0] i_axi_araddr;
    reg                  i_axi_arvalid;
    wire                 o_axi_arready;
    reg [2:0]            i_axi_arprot;

    wire [DATA_WIDTH-1:0] o_axi_rdata;
    wire                  o_axi_rvalid;
    wire [1:0]            o_axi_rresp;
    reg                   i_axi_rready;

    // Instantiate DUT (Device Under Test)
    TIMER_axi_lite_core #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CYCLE_CLOCK(CYCLE_CLOCK),
        .ADDR_REGISTERS_0(ADDR_REG0)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .i_axi_awaddr(i_axi_awaddr),
        .i_axi_awvalid(i_axi_awvalid),
        .o_axi_awready(o_axi_awready),
        .i_axi_awprot(i_axi_awprot),
        .i_axi_wdata(i_axi_wdata),
        .i_axi_wstrb(i_axi_wstrb),
        .i_axi_wvalid(i_axi_wvalid),
        .o_axi_wready(o_axi_wready),
        .o_axi_bresp(o_axi_bresp),
        .o_axi_bvalid(o_axi_bvalid),
        .i_axi_bready(i_axi_bready),
        .i_axi_araddr(i_axi_araddr),
        .i_axi_arvalid(i_axi_arvalid),
        .o_axi_arready(o_axi_arready),
        .i_axi_arprot(i_axi_arprot),
        .o_axi_rdata(o_axi_rdata),
        .o_axi_rvalid(o_axi_rvalid),
        .o_axi_rresp(o_axi_rresp),
        .i_axi_rready(i_axi_rready)
    );

    // Clock generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- AXI-Lite Write Task ---
    task axi_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            i_axi_awaddr = addr;
            i_axi_awvalid = 1;
            i_axi_wdata = data;
            i_axi_wstrb = 4'hF;
            i_axi_wvalid = 1;
            i_axi_bready = 1;

            wait(o_axi_awready && o_axi_wready);
            @(posedge clk);
            i_axi_awvalid = 0;
            i_axi_wvalid = 0;

            wait(o_axi_bvalid);
            @(posedge clk);
            i_axi_bready = 0;
            $display("[WRITE] Addr: 0x%h, Data: 0x%h", addr, data);
        end
    endtask

    // --- AXI-Lite Read Task (Tách biệt AR và R) ---
    task axi_read(input [ADDR_WIDTH-1:0] addr);
        begin
            // --- Giai đoạn 1: Kênh Địa chỉ Đọc (AR Channel) ---
            @(posedge clk);
            i_axi_araddr  = addr;
            i_axi_arvalid = 1;

            // Chờ cho đến khi Slave sẵn sàng nhận địa chỉ (arready)
            wait(o_axi_arready);
            @(posedge clk);
            i_axi_arvalid = 0; // Sau khi handshake xong thì hạ valid
            i_axi_araddr  = 0;

            // --- Giai đoạn 2: Kênh Dữ liệu Đọc (R Channel) ---
            i_axi_rready  = 1; // Sẵn sàng nhận dữ liệu phản hồi

            // Chờ cho đến khi Slave đưa dữ liệu lên (rvalid)
            wait(o_axi_rvalid);
            $display("[READ AT TIME %t] Addr: 0x%h, Data: 0x%h, Resp: %b", $time, addr, o_axi_rdata, o_axi_rresp);
            
            @(posedge clk);
            i_axi_rready  = 0; // Kết thúc giao dịch đọc
        end
    endtask

    // --- Main Test Sequence ---
    initial begin
        // Initialize signals
        resetn = 0;
        i_axi_awaddr = 0; i_axi_awvalid = 0; i_axi_awprot = 0;
        i_axi_wdata = 0; i_axi_wstrb = 0; i_axi_wvalid = 0;
        i_axi_bready = 0;
        i_axi_araddr = 0; i_axi_arvalid = 0; i_axi_arprot = 0;
        i_axi_rready = 0;

        // Reset
        #50;
        resetn = 1;
        #20;

        $display("----- Starting Timer Test -----");

        // 1. Start Timer (Set bit 0 of write data)
        axi_write(ADDR_REG0, 32'h0000_0001);
        
        // 2. Wait for timer to tick (e.g., 100 cycles)
        repeat(100) @(posedge clk);

        // 3. Read lower 32 bits of counter (any address except REG0)
        axi_read(ADDR_REG_LOW);

        // 4. Read upper bits of counter (ADDR_REG0)
        axi_read(ADDR_REG0);

        // 5. Clear Timer (Set bit 1 of write data)
        $display("----- Clearing Timer -----");
        axi_write(ADDR_REG0, 32'h0000_0002);
        
        // 6. Read again to verify it is 0
        #20;
        axi_read(ADDR_REG_LOW);

        #100;
        $display("----- Test Completed -----");
        $finish;
    end

endmodule