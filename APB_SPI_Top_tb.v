// ============================================================
// APB_SPI_Top_tb.v  –  Testbench for APB_SPI_Top
// ModelSim / Quartus 18.1
// ============================================================
`timescale 1ns/1ps

module APB_SPI_Top_tb;

    // -------------------------------------------------------
    // DUT ports
    // -------------------------------------------------------
    reg        PCLK, PRESETn;
    reg        PSEL, PENABLE, PWRITE;
    reg        miso;
    reg  [2:0] PADDR;
    reg  [7:0] PWDATA;

    wire [7:0] PRDATA;
    wire       PREADY, PSLVERR;
    wire       sclk, ss, mosi;
    wire       spi_interrupt_request;

    // -------------------------------------------------------
    // DUT
    // -------------------------------------------------------
    APB_SPI_Top DUT (
        .PCLK                 (PCLK),
        .PRESETn              (PRESETn),
        .PSEL                 (PSEL),
        .PENABLE              (PENABLE),
        .PWRITE               (PWRITE),
        .miso                 (miso),
        .PADDR                (PADDR),
        .PWDATA               (PWDATA),
        .PRDATA               (PRDATA),
        .PREADY               (PREADY),
        .PSLVERR              (PSLVERR),
        .sclk                 (sclk),
        .ss                   (ss),
        .mosi                 (mosi),
        .spi_interrupt_request(spi_interrupt_request)
    );

    // -------------------------------------------------------
    // 50 MHz clock  (20 ns period)
    // -------------------------------------------------------
    initial PCLK = 0;
    always  #10 PCLK = ~PCLK;

    // -------------------------------------------------------
    // APB Write task
    // ADDR map (matches SPI_APB_Slave_Interface):
    //   0x0 = SPI_CR1   0x1 = SPI_CR2
    //   0x2 = SPI_BR    0x3 = SPI_SR (read only)
    //   0x4 = SPI_DR    (write = TX,  read = RX)
    // -------------------------------------------------------
    task apb_write;
        input [2:0] addr;
        input [7:0] data;
        begin
            @(posedge PCLK); #1;
            PADDR   = addr;
            PWDATA  = data;
            PWRITE  = 1'b1;
            PSEL    = 1'b1;
            PENABLE = 1'b0;
            @(posedge PCLK); #1;
            PENABLE = 1'b1;
            @(posedge PCLK);
            while (!PREADY) @(posedge PCLK);
            #1;
            PSEL    = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
        end
    endtask

    // -------------------------------------------------------
    // APB Read task
    // -------------------------------------------------------
    task apb_read;
        input  [2:0] addr;
        output [7:0] rdata;
        begin
            @(posedge PCLK); #1;
            PADDR   = addr;
            PWRITE  = 1'b0;
            PSEL    = 1'b1;
            PENABLE = 1'b0;
            @(posedge PCLK); #1;
            PENABLE = 1'b1;
            @(posedge PCLK);
            while (!PREADY) @(posedge PCLK);
            rdata = PRDATA;
            #1;
            PSEL    = 1'b0;
            PENABLE = 1'b0;
        end
    endtask

    // -------------------------------------------------------
    // Simple MISO slave: echoes 0xB4 on sclk edges
    // -------------------------------------------------------
    reg [7:0] miso_byte;
    integer   miso_bit;

    initial begin
        miso      = 1'b0;
        miso_byte = 8'hB4;
        miso_bit  = 7;
    end

    always @(negedge ss) begin
        miso_byte = 8'hB4;
        miso_bit  = 7;
    end

    always @(posedge sclk) begin
        if (!ss) begin
            miso     = miso_byte[miso_bit];
            miso_bit = (miso_bit == 0) ? 7 : miso_bit - 1;
        end
    end

    // -------------------------------------------------------
    // Test variables
    // -------------------------------------------------------
    reg [7:0] rd_data;
    integer   i;

    // -------------------------------------------------------
    // SPI_CR1 bit encoding (from SPI_APB_Slave_Interface):
    //   [7]=mstr [6]=cpol [5]=cpha [4]=lsbfe [3]=spie [1:0]=spi_mode
    // SPI_BR  encoding:
    //   [7:5]=spiswai [4:2]=sppr [2:0]=spr
    // -------------------------------------------------------
    // Mode 0: cpol=0 cpha=0  CR1 = 1000_0000 = 0x80  (master, mode0)
    // Mode 1: cpol=0 cpha=1  CR1 = 1010_0000 = 0xA0
    // Mode 2: cpol=1 cpha=0  CR1 = 1100_0000 = 0xC0
    // Mode 3: cpol=1 cpha=1  CR1 = 1110_0000 = 0xE0

    initial begin
        $dumpfile("APB_SPI_Top_tb.vcd");
        $dumpvars(0, APB_SPI_Top_tb);

        // Initialise bus
        PRESETn = 0; PSEL = 0; PENABLE = 0;
        PWRITE  = 0; PADDR = 0; PWDATA  = 0;

        repeat(6) @(posedge PCLK);
        PRESETn = 1;
        repeat(3) @(posedge PCLK);

        // --------------------------------------------------
        $display("=== TEST 1: SPI Mode 0 – send 0xA5 ===");
        // --------------------------------------------------
        apb_write(3'h0, 8'h80);   // CR1: master, cpol=0, cpha=0
        apb_write(3'h2, 8'h00);   // BR : fastest (sppr=0, spr=0)
        apb_write(3'h4, 8'hA5);   // DR write → triggers TX

        // Wait for transfer (ss goes high = done)
        wait(ss == 1'b0);         // SS asserted
        wait(ss == 1'b1);         // SS deasserted (done)
        repeat(5) @(posedge PCLK);

        apb_read(3'h4, rd_data);
        $display("  Mode0  TX=0xA5  RX=0x%02h  (slave sent 0xB4)", rd_data);

        // --------------------------------------------------
        $display("=== TEST 2: SPI Mode 1 – send 0x3C ===");
        // --------------------------------------------------
        apb_write(3'h0, 8'hA0);   // CR1: master, cpha=1
        apb_write(3'h4, 8'h3C);
        wait(ss == 1'b0); wait(ss == 1'b1);
        repeat(5) @(posedge PCLK);
        apb_read(3'h4, rd_data);
        $display("  Mode1  TX=0x3C  RX=0x%02h", rd_data);

        // --------------------------------------------------
        $display("=== TEST 3: SPI Mode 2 – send 0xFF ===");
        // --------------------------------------------------
        apb_write(3'h0, 8'hC0);   // cpol=1, cpha=0
        apb_write(3'h4, 8'hFF);
        wait(ss == 1'b0); wait(ss == 1'b1);
        repeat(5) @(posedge PCLK);
        apb_read(3'h4, rd_data);
        $display("  Mode2  TX=0xFF  RX=0x%02h", rd_data);

        // --------------------------------------------------
        $display("=== TEST 4: SPI Mode 3 – send 0x0F ===");
        // --------------------------------------------------
        apb_write(3'h0, 8'hE0);   // cpol=1, cpha=1
        apb_write(3'h4, 8'h0F);
        wait(ss == 1'b0); wait(ss == 1'b1);
        repeat(5) @(posedge PCLK);
        apb_read(3'h4, rd_data);
        $display("  Mode3  TX=0x0F  RX=0x%02h", rd_data);

        // --------------------------------------------------
        $display("=== TEST 5: Back-to-back transfers ===");
        // --------------------------------------------------
        apb_write(3'h0, 8'h80);   // back to Mode 0
        for (i = 0; i < 4; i = i + 1) begin
            apb_write(3'h4, i[7:0]);
            wait(ss == 1'b0); wait(ss == 1'b1);
            repeat(5) @(posedge PCLK);
            apb_read(3'h4, rd_data);
            $display("  B2B[%0d]  TX=0x%02h  RX=0x%02h", i, i[7:0], rd_data);
        end

        // --------------------------------------------------
        $display("=== TEST 6: Status & interrupt check ===");
        // --------------------------------------------------
        apb_read(3'h3, rd_data);
        $display("  SPI_SR = 0x%02h", rd_data);
        $display("  spi_interrupt_request = %0b", spi_interrupt_request);

        // --------------------------------------------------
        $display("=== TEST 7: LSB-first transfer ===");
        // --------------------------------------------------
        apb_write(3'h0, 8'h90);   // CR1: master + lsbfe=1
        apb_write(3'h4, 8'hC3);
        wait(ss == 1'b0); wait(ss == 1'b1);
        repeat(5) @(posedge PCLK);
        apb_read(3'h4, rd_data);
        $display("  LSBfirst TX=0xC3  RX=0x%02h", rd_data);

        $display("=== All tests done ===");
        repeat(20) @(posedge PCLK);
        $finish;
    end

    // -------------------------------------------------------
    // Watchdog
    // -------------------------------------------------------
    initial begin
        #5_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule