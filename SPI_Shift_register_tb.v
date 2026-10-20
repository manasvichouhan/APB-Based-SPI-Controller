`timescale 1ns/1ps
 
module SPI_Shift_register_tb;
 
    // -------------------------------------------------------
    // DUT port connections
    // -------------------------------------------------------
    reg        PCLK;
    reg        PRESET_n;
    reg        ss_i;
    reg        send_data_i;
    reg        lsbfe_i;
    reg        cpha_i;
    reg        cpol_i;
    reg        miso_receive_sclk_i;
    reg        miso_receive_sclk0_i;
    reg        mosi_send_sclk_i;
    reg        mosi_send_sclk0_i;
    reg [7:0]  data_mosi_i;
    reg        miso_i;
    reg        receive_data_i;
 
    wire       mosi_o;
    wire [7:0] data_miso_o;
 
    // -------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------
    integer    i;
    integer    test_num;
    reg [7:0]  mosi_captured;   // shift-in MOSI bits during TB
    reg [7:0]  miso_pattern;    // pattern driven on miso_i
 
    // -------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------
    SPI_Shift_register dut (
        .PCLK                 (PCLK),
        .PRESET_n             (PRESET_n),
        .ss_i                 (ss_i),
        .send_data_i          (send_data_i),
        .lsbfe_i              (lsbfe_i),
        .cpha_i               (cpha_i),
        .cpol_i               (cpol_i),
        .miso_receive_sclk_i  (miso_receive_sclk_i),
        .miso_receive_sclk0_i (miso_receive_sclk0_i),
        .mosi_send_sclk_i     (mosi_send_sclk_i),
        .mosi_send_sclk0_i    (mosi_send_sclk0_i),
        .data_mosi_i          (data_mosi_i),
        .miso_i               (miso_i),
        .receive_data_i       (receive_data_i),
        .mosi_o               (mosi_o),
        .data_miso_o          (data_miso_o)
    );
 
    // -------------------------------------------------------
    // Clock : 10 ns period  (100 MHz PCLK)
    // -------------------------------------------------------
    initial PCLK = 0;
    always #5 PCLK = ~PCLK;
 
    // -------------------------------------------------------
    // SCLK helper: generates one SPI clock pulse pair
    //   rising-edge strobe  → mosi_send_sclk_i / miso_receive_sclk_i
    //   falling-edge strobe → mosi_send_sclk0_i / miso_receive_sclk0_i
    // -------------------------------------------------------
    task spi_clock_pulse;
        input use_cpha1; // 0 = CPHA0  (sample rise), 1 = CPHA1 (sample fall)
        begin
            // --- Rising edge pulse ---
            @(posedge PCLK); #1;
            mosi_send_sclk_i      <= 1'b1;
            miso_receive_sclk_i   <= 1'b1;
            mosi_send_sclk0_i     <= 1'b0;
            miso_receive_sclk0_i  <= 1'b0;
 
            @(posedge PCLK); #1;
            mosi_send_sclk_i      <= 1'b0;
            miso_receive_sclk_i   <= 1'b0;
 
            // --- Falling edge pulse ---
            @(posedge PCLK); #1;
            mosi_send_sclk0_i     <= 1'b1;
            miso_receive_sclk0_i  <= 1'b1;
 
            @(posedge PCLK); #1;
            mosi_send_sclk0_i     <= 1'b0;
            miso_receive_sclk0_i  <= 1'b0;
        end
    endtask
 
    // -------------------------------------------------------
    // Full 8-bit SPI transfer helper
    //   data   : byte to load into shift register
    //   lsb    : lsbfe_i value
    //   cpha   : cpha_i value
    //   miso_p : 8-bit pattern presented on miso_i (MSB first)
    // -------------------------------------------------------
    task spi_transfer;
        input [7:0] data;
        input       lsb;
        input       cpha;
        input [7:0] miso_p;
        begin
            // Configure
            lsbfe_i        = lsb;
            cpha_i         = cpha;
            miso_pattern   = miso_p;
            data_mosi_i    = data;
 
            // Assert SS and load
            @(posedge PCLK); #1;
            ss_i           = 1'b0;
            send_data_i    = 1'b1;
            receive_data_i = 1'b1;
 
            @(posedge PCLK); #1;
            send_data_i    = 1'b0;
 
            // Drive 8 SPI clock pulses; present MISO bit before each sample
            for (i = 0; i < 8; i = i + 1) begin
                // Present MISO bit (MSB first of miso_pattern)
                miso_i = miso_pattern[7 - i];
 
                // One SPI clock cycle
                spi_clock_pulse(cpha);
            end
 
            // De-assert SS
            @(posedge PCLK); #1;
            ss_i           = 1'b1;
            receive_data_i = 1'b0;
            miso_i         = 1'b0;
 
            // Small gap between transfers
            repeat(4) @(posedge PCLK);
        end
    endtask
 
    // -------------------------------------------------------
    // Checker helper
    // -------------------------------------------------------
    task check;
        input [7:0] expected_miso;
        input [7:0] test_id;
        begin
            $display("--- TC%0d: data_miso_o = 8'h%02h  (expected 8'h%02h) %s",
                     test_id, data_miso_o, expected_miso,
                     (data_miso_o === expected_miso) ? "PASS" : "FAIL ***");
        end
    endtask
 
    // -------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------
    initial begin
        // ---- Initialise all inputs ----
        PRESET_n              = 1'b1;
        ss_i                  = 1'b1;
        send_data_i           = 1'b0;
        lsbfe_i               = 1'b0;
        cpha_i                = 1'b0;
        cpol_i                = 1'b0;
        miso_receive_sclk_i   = 1'b0;
        miso_receive_sclk0_i  = 1'b0;
        mosi_send_sclk_i      = 1'b0;
        mosi_send_sclk0_i     = 1'b0;
        data_mosi_i           = 8'h00;
        miso_i                = 1'b0;
        receive_data_i        = 1'b0;
 
        // ---- Apply reset ----
        @(posedge PCLK); #1;
        PRESET_n = 1'b0;
        repeat(4) @(posedge PCLK);
        PRESET_n = 1'b1;
        repeat(2) @(posedge PCLK);
 
        $display("========================================");
        $display("  SPI Shift Register Testbench Start   ");
        $display("========================================");
 
        // ================================================
        // TC1: MSB-first, CPHA=0  data=8'h0A  miso=8'hB5
        // ================================================
        $display("\nTC1 : MSB-first | CPHA=0 | TX=0x0A | MISO=0xB5");
        spi_transfer(8'h0A, 1'b0, 1'b0, 8'hB5);
        check(8'hB5, 1);
 
        // ================================================
        // TC2: LSB-first, CPHA=0  data=8'h0A  miso=8'hB5
        //      When driven MSB-first on miso line but
        //      received LSB-first → result is bit-reversed B5 = 0xAD
        // ================================================
        $display("\nTC2 : LSB-first | CPHA=0 | TX=0x0A | MISO=0xB5");
        spi_transfer(8'h0A, 1'b1, 1'b0, 8'hB5);
        // LSB-first shifts right: first miso bit (B[7]=1) → data_miso_o[7]
        // full capture = 8'hAD  (bit-reverse of B5)
        check(8'hAD, 2);
 
        // ================================================
        // TC3: MSB-first, CPHA=1  data=8'hFF  miso=8'h00
        // ================================================
        $display("\nTC3 : MSB-first | CPHA=1 | TX=0xFF | MISO=0x00");
        spi_transfer(8'hFF, 1'b0, 1'b1, 8'h00);
        check(8'h00, 3);
 
        // ================================================
        // TC4: MSB-first, CPHA=0  data=8'hA5  miso=8'hA5
        // ================================================
        $display("\nTC4 : MSB-first | CPHA=0 | TX=0xA5 | MISO=0xA5");
        spi_transfer(8'hA5, 1'b0, 1'b0, 8'hA5);
        check(8'hA5, 4);
 
        // ================================================
        // TC5: MSB-first, CPHA=0  data=8'hFF  miso=8'hFF
        // ================================================
        $display("\nTC5 : MSB-first | CPHA=0 | TX=0xFF | MISO=0xFF");
        spi_transfer(8'hFF, 1'b0, 1'b0, 8'hFF);
        check(8'hFF, 5);
 
        // ================================================
        // TC6: MSB-first, CPHA=0  data=8'h55  miso=8'hAA
        // ================================================
        $display("\nTC6 : MSB-first | CPHA=0 | TX=0x55 | MISO=0xAA");
        spi_transfer(8'h55, 1'b0, 1'b0, 8'hAA);
        check(8'hAA, 6);
 
        // ================================================
        // TC7: LSB-first, CPHA=1  data=8'hC3  miso=8'hC3
        //      Driven MSB-first → bit-reversed = 0xC3
        //      (0xC3 is its own bit-reverse for this pattern)
        // ================================================
        $display("\nTC7 : LSB-first | CPHA=1 | TX=0xC3 | MISO=0xC3");
        spi_transfer(8'hC3, 1'b1, 1'b1, 8'hC3);
        check(8'hC3, 7);
 
        // ================================================
        // TC8: Back-to-back MSB-first, CPHA=0
        //      Transfer 1: data=8'h12  miso=8'h34
        //      Transfer 2: data=8'h56  miso=8'h78
        // ================================================
        $display("\nTC8a: Back-to-back 1/2 | TX=0x12 | MISO=0x34");
        spi_transfer(8'h12, 1'b0, 1'b0, 8'h34);
        check(8'h34, 8);
 
        $display("\nTC8b: Back-to-back 2/2 | TX=0x56 | MISO=0x78");
        spi_transfer(8'h56, 1'b0, 1'b0, 8'h78);
        check(8'h78, 9);
 
        // ================================================
        // TC9: Reset during transfer – verify clean restart
        // ================================================
        $display("\nTC9 : Reset mid-transfer check");
        ss_i        = 1'b0;
        send_data_i = 1'b1;
        data_mosi_i = 8'hDE;
        @(posedge PCLK); #1;
        send_data_i = 1'b0;
        // 3 SPI pulses then reset
        repeat(3) spi_clock_pulse(0);
        PRESET_n = 1'b0;
        repeat(2) @(posedge PCLK);
        PRESET_n = 1'b1;
        ss_i     = 1'b1;
        @(posedge PCLK);
        $display("    After reset: mosi_o=%0b  data_miso_o=0x%02h  (expect 0x00)",
                 mosi_o, data_miso_o);
        if (data_miso_o === 8'h00 && mosi_o === 1'b0)
            $display("    TC9 PASS");
        else
            $display("    TC9 FAIL ***");
 
        // ================================================
        // TC10: SS de-asserted mid-transfer
        //       MOSI should go low when SS de-asserts
        // ================================================
        $display("\nTC10: SS de-assert mid-transfer");
        ss_i        = 1'b0;
        send_data_i = 1'b1;
        data_mosi_i = 8'hAB;
        @(posedge PCLK); #1;
        send_data_i = 1'b0;
        repeat(4) spi_clock_pulse(0);   // 4 bits then de-select
        ss_i = 1'b1;
        @(posedge PCLK); #1;
        $display("    mosi_o after SS high = %0b  (expect 0)", mosi_o);
        if (mosi_o === 1'b0)
            $display("    TC10 PASS");
        else
            $display("    TC10 FAIL ***");
 
        repeat(5) @(posedge PCLK);
 
        $display("\n========================================");
        $display("  Simulation complete                   ");
        $display("========================================");
        $finish;
    end
 
    // -------------------------------------------------------
    // Waveform dump for ModelSim
    // -------------------------------------------------------
    initial begin
        $dumpfile("SPI_Shift_register_tb.vcd");
        $dumpvars(0, SPI_Shift_register_tb);
    end
 
endmodule