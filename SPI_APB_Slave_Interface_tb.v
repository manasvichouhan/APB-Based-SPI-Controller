// ============================================================
// Module      : SPI_APB_Slave_Interface_tb
// Project     : APB-Based SPI
// Tool        : Quartus 18.1 / ModelSim
// Description : Testbench for SPI_APB_Slave_Interface with
//               multiple APB write/read test cases covering
//               all register addresses, reset behaviour,
//               interrupt, and back-to-back transfers.
// ============================================================

`timescale 1ns/1ps

module SPI_APB_Slave_Interface_tb;

    // -------------------------------------------------------
    // DUT port connections
    // -------------------------------------------------------
    reg        PCLK;
    reg        PRESET_n;
    reg [2:0]  PADDR_i;
    reg        PWRITE_i;
    reg        PSEL_i;
    reg        PENABLE_i;
    reg [7:0]  PWDATA_i;
    reg        ss_i;
    reg [7:0]  miso_data_i;
    reg        receive_data_i;
    reg        tip_i;

    wire [7:0] PRDATA_o;
    wire       PREADY_o;
    wire       PSLVERR_o;
    wire       mstr_o;
    wire       cpol_o;
    wire       cpha_o;
    wire       lsbfe_o;
    wire [2:0] spiswai_o;
    wire [2:0] sppr_o;
    wire [2:0] spr_o;
    wire       spi_interrupt_request_o;
    wire       send_data_o;
    wire [7:0] mosi_data_o;
    wire [1:0] spi_mode_o;

    // -------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------
    SPI_APB_Slave_Interface dut (
        .PCLK                    (PCLK),
        .PRESET_n                (PRESET_n),
        .PADDR_i                 (PADDR_i),
        .PWRITE_i                (PWRITE_i),
        .PSEL_i                  (PSEL_i),
        .PENABLE_i               (PENABLE_i),
        .PWDATA_i                (PWDATA_i),
        .ss_i                    (ss_i),
        .miso_data_i             (miso_data_i),
        .receive_data_i          (receive_data_i),
        .tip_i                   (tip_i),
        .PRDATA_o                (PRDATA_o),
        .PREADY_o                (PREADY_o),
        .PSLVERR_o               (PSLVERR_o),
        .mstr_o                  (mstr_o),
        .cpol_o                  (cpol_o),
        .cpha_o                  (cpha_o),
        .lsbfe_o                 (lsbfe_o),
        .spiswai_o               (spiswai_o),
        .sppr_o                  (sppr_o),
        .spr_o                   (spr_o),
        .spi_interrupt_request_o (spi_interrupt_request_o),
        .send_data_o             (send_data_o),
        .mosi_data_o             (mosi_data_o),
        .spi_mode_o              (spi_mode_o)
    );

    // -------------------------------------------------------
    // Clock : 10 ns (100 MHz)
    // -------------------------------------------------------
    initial PCLK = 0;
    always #5 PCLK = ~PCLK;

    // -------------------------------------------------------
    // APB Write task  (2-phase: SETUP → ENABLE)
    // -------------------------------------------------------
    task apb_write;
        input [2:0]  addr;
        input [7:0]  data;
        begin
            // SETUP phase
            @(posedge PCLK); #1;
            PSEL_i    = 1'b1;
            PWRITE_i  = 1'b1;
            PADDR_i   = addr;
            PWDATA_i  = data;
            PENABLE_i = 1'b0;

            // ENABLE phase
            @(posedge PCLK); #1;
            PENABLE_i = 1'b1;

            // Wait for PREADY
            @(posedge PCLK); #1;
            PSEL_i    = 1'b0;
            PENABLE_i = 1'b0;
            PWRITE_i  = 1'b0;
        end
    endtask

    // -------------------------------------------------------
    // APB Read task
    // -------------------------------------------------------
    task apb_read;
        input  [2:0]  addr;
        output [7:0]  rdata;
        begin
            // SETUP phase
            @(posedge PCLK); #1;
            PSEL_i    = 1'b1;
            PWRITE_i  = 1'b0;
            PADDR_i   = addr;
            PWDATA_i  = 8'h00;
            PENABLE_i = 1'b0;

            // ENABLE phase
            @(posedge PCLK); #1;
            PENABLE_i = 1'b1;

            @(posedge PCLK); #1;
            rdata     = PRDATA_o;
            PSEL_i    = 1'b0;
            PENABLE_i = 1'b0;
        end
    endtask

    // -------------------------------------------------------
    // Checker
    // -------------------------------------------------------
    task check;
        input [7:0]  got;
        input [7:0]  exp;
        input [7:0]  tc;
        begin
            $display("  TC%0d: got=0x%02h  exp=0x%02h  %s",
                     tc, got, exp,
                     (got === exp) ? "PASS" : "FAIL ***");
        end
    endtask

    reg [7:0] rd_data;
    integer   i;

    // -------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------
    initial begin
        // Default APB bus idle
        PRESET_n      = 1'b1;
        PSEL_i        = 1'b0;
        PENABLE_i     = 1'b0;
        PWRITE_i      = 1'b0;
        PADDR_i       = 3'b000;
        PWDATA_i      = 8'h00;
        ss_i          = 1'b1;
        miso_data_i   = 8'h00;
        receive_data_i= 1'b0;
        tip_i         = 1'b0;

        // Apply reset
        @(posedge PCLK); #1;
        PRESET_n = 1'b0;
        repeat(4) @(posedge PCLK);
        PRESET_n = 1'b1;
        repeat(2) @(posedge PCLK);

        $display("============================================");
        $display("  SPI APB Slave Interface Testbench Start  ");
        $display("============================================");

        // ================================================
        // TC1: Write 0xA6 to CR1 (addr=000)
        //      Expect: mstr=1, cpol=0, cpha=1, lsbfe=0
        //      0xA6 = 1010_0110
        //             mstr=1, cpol=0, cpha=1, lsbfe=0, spie=0, spi_mode=10
        // ================================================
        $display("\n[TC1] Write CR1 = 0xA6");
        apb_write(3'b000, 8'hA6);
        repeat(2) @(posedge PCLK);
        $display("  mstr=%0b cpol=%0b cpha=%0b lsbfe=%0b spi_mode=%02b",
                 mstr_o, cpol_o, cpha_o, lsbfe_o, spi_mode_o);
        if (mstr_o===1'b1 && cpha_o===1'b1 && lsbfe_o===1'b0)
            $display("  TC1 PASS");
        else
            $display("  TC1 FAIL ***");

        // ================================================
        // TC2: Read back CR1 from addr=000 → expect 0xA6
        // ================================================
        $display("\n[TC2] Read CR1");
        apb_read(3'b000, rd_data);
        check(rd_data, 8'hA6, 2);

        // ================================================
        // TC3: Write CR2 = 0x56 (addr=001)
        // ================================================
        $display("\n[TC3] Write CR2 = 0x56");
        apb_write(3'b001, 8'h56);
        repeat(2) @(posedge PCLK);
        apb_read(3'b001, rd_data);
        check(rd_data, 8'h56, 3);

        // ================================================
        // TC4: Write Baud Rate reg = 0x4A (addr=010)
        //      spiswai=010, sppr=010, spr=010
        // ================================================
        $display("\n[TC4] Write BR = 0x4A");
        apb_write(3'b010, 8'h4A);
        repeat(2) @(posedge PCLK);
        $display("  spiswai=%03b  sppr=%03b  spr=%03b",
                 spiswai_o, sppr_o, spr_o);
        apb_read(3'b010, rd_data);
        check(rd_data, 8'h4A, 4);

        // ================================================
        // TC5: Write Data Register = 0x0A (addr=100)
        //      Expect send_data_o pulse and mosi_data_o=0x0A
        // ================================================
        $display("\n[TC5] Write DR = 0x0A (TX trigger)");
        apb_write(3'b100, 8'h0A);
        @(posedge PCLK); #1;
        $display("  send_data_o=%0b  mosi_data_o=0x%02h  (expect send=1,data=0x0A)",
                 send_data_o, mosi_data_o);
        if (mosi_data_o === 8'h0A)
            $display("  TC5 PASS");
        else
            $display("  TC5 FAIL ***");

        // ================================================
        // TC6: Read Status Register (addr=011) with
        //      receive_data_i=1 and tip_i=1
        // ================================================
        $display("\n[TC6] Read SR with receive_data_i=1, tip_i=1");
        receive_data_i = 1'b1;
        tip_i          = 1'b1;
        repeat(2) @(posedge PCLK);
        apb_read(3'b011, rd_data);
        $display("  SR=0x%02h  SR[7]=%0b(expect 1)  SR[4]=%0b(expect 1)",
                 rd_data, rd_data[7], rd_data[4]);
        if (rd_data[7] === 1'b1 && rd_data[4] === 1'b1)
            $display("  TC6 PASS");
        else
            $display("  TC6 FAIL ***");

        // ================================================
        // TC7: Read RX Data (addr=100) with miso_data_i=0xB5
        // ================================================
        $display("\n[TC7] Read MISO data = 0xB5");
        miso_data_i = 8'hB5;
        apb_read(3'b100, rd_data);
        check(rd_data, 8'hB5, 7);

        // ================================================
        // TC8: Interrupt request check
        //      CR1[3]=SPIE=1 → write 0xA8 to CR1, SPIF=1
        // ================================================
        $display("\n[TC8] Interrupt request check");
        receive_data_i = 1'b1;
        apb_write(3'b000, 8'hA8);   // set SPIE bit (CR1[3]=1)
        repeat(3) @(posedge PCLK);
        $display("  spi_interrupt_request_o=%0b  (expect 1)",
                 spi_interrupt_request_o);
        if (spi_interrupt_request_o === 1'b1)
            $display("  TC8 PASS");
        else
            $display("  TC8 FAIL ***");
        receive_data_i = 1'b0;

        // ================================================
        // TC9: Back-to-back writes to DR (different data)
        // ================================================
        $display("\n[TC9] Back-to-back DR writes: 0x12, 0x34, 0x56");
        apb_write(3'b100, 8'h12);
        @(posedge PCLK);
        apb_write(3'b100, 8'h34);
        @(posedge PCLK);
        apb_write(3'b100, 8'h56);
        repeat(2) @(posedge PCLK);
        $display("  Last mosi_data_o=0x%02h  (expect 0x56)", mosi_data_o);
        if (mosi_data_o === 8'h56)
            $display("  TC9 PASS");
        else
            $display("  TC9 FAIL ***");

        // ================================================
        // TC10: Reset during active write → registers clear
        // ================================================
        $display("\n[TC10] Reset mid-operation");
        PSEL_i    = 1'b1;
        PWRITE_i  = 1'b1;
        PADDR_i   = 3'b000;
        PWDATA_i  = 8'hFF;
        @(posedge PCLK); #1;
        PRESET_n = 1'b0;           // assert reset during SETUP
        repeat(3) @(posedge PCLK);
        PRESET_n  = 1'b1;
        PSEL_i    = 1'b0;
        PENABLE_i = 1'b0;
        PWRITE_i  = 1'b0;
        repeat(2) @(posedge PCLK);
        // After reset all outputs should be 0
        $display("  mstr=%0b cpol=%0b cpha=%0b lsbfe=%0b mosi_data=0x%02h (all expect 0)",
                 mstr_o, cpol_o, cpha_o, lsbfe_o, mosi_data_o);
        if (mstr_o===0 && cpol_o===0 && cpha_o===0 && mosi_data_o===8'h00)
            $display("  TC10 PASS");
        else
            $display("  TC10 FAIL ***");

        // ================================================
        // TC11: PSLVERR should remain 0 (no error)
        // ================================================
        $display("\n[TC11] PSLVERR should stay 0");
        apb_write(3'b000, 8'h82);
        apb_read (3'b000, rd_data);
        $display("  PSLVERR=%0b  (expect 0)", PSLVERR_o);
        if (PSLVERR_o === 1'b0)
            $display("  TC11 PASS");
        else
            $display("  TC11 FAIL ***");

        // ================================================
        // TC12: Write LSB-first mode (lsbfe=1)
        //       CR1 = 0b_1001_0000 = 0x90
        // ================================================
        $display("\n[TC12] LSB-first mode via CR1=0x90");
        apb_write(3'b000, 8'h90);
        repeat(2) @(posedge PCLK);
        $display("  lsbfe_o=%0b  (expect 1)", lsbfe_o);
        if (lsbfe_o === 1'b1)
            $display("  TC12 PASS");
        else
            $display("  TC12 FAIL ***");

        repeat(5) @(posedge PCLK);

        $display("\n============================================");
        $display("  Simulation complete                       ");
        $display("============================================");
        $finish;
    end

    // -------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------
    initial begin
        $dumpfile("SPI_APB_Slave_Interface_tb.vcd");
        $dumpvars(0, SPI_APB_Slave_Interface_tb);
    end

endmodule