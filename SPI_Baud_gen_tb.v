`timescale 1ps/1ps
 
module SPI_Baud_gen_tb;
 
    // -------------------------------------------------------
    // DUT Inputs
    // -------------------------------------------------------
    reg        PCLK;
    reg        PRESET_n;
    reg        spiswai_i;
    reg        cpol_i;
    reg        cpha_i;
    reg        ss_i;
    reg [2:0]  sppr_i;
    reg [2:0]  spr_i;
    reg [1:0]  spi_mode_i;
 
    // -------------------------------------------------------
    // DUT Outputs
    // -------------------------------------------------------
    wire        sclk_o;
    wire        miso_receive_sclk_o;
    wire        miso_receive_sclk0_o;
    wire        mosi_send_sclk_o;
    wire        mosi_send_sclk0_o;
    wire [11:0] baudratedivisor_o;
 
    // -------------------------------------------------------
    // Loop variables
    // -------------------------------------------------------
    integer j;
    integer i;
 
    // -------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------
    SPI_Baud_gen uut (
        .PCLK                 (PCLK),
        .PRESET_n             (PRESET_n),
        .spiswai_i            (spiswai_i),
        .cpol_i               (cpol_i),
        .cpha_i               (cpha_i),
        .ss_i                 (ss_i),
        .sppr_i               (sppr_i),
        .spr_i                (spr_i),
        .spi_mode_i           (spi_mode_i),
        .sclk_o               (sclk_o),
        .miso_receive_sclk_o  (miso_receive_sclk_o),
        .miso_receive_sclk0_o (miso_receive_sclk0_o),
        .mosi_send_sclk_o     (mosi_send_sclk_o),
        .mosi_send_sclk0_o    (mosi_send_sclk0_o),
        .baudratedivisor_o    (baudratedivisor_o)
    );
 
    // -------------------------------------------------------
    // Clock Generation: 100 ps period => 10 GHz (adjust as needed)
    // For 50 MHz PCLK use 20ns period => change to #10
    // -------------------------------------------------------
    initial PCLK = 0;
    always #10 PCLK = ~PCLK; // 20ps period => use for fast sim
 
    // -------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------
    initial begin
        // ---- Initialize ----
        PRESET_n   = 0;
        spiswai_i  = 0;
        cpol_i     = 0;
        cpha_i     = 0;
        ss_i       = 1;     // Deassert SS (active low logic: 1=idle)
        sppr_i     = 3'b000; // SPPR = 0
        spr_i      = 3'b010; // SPR  = 2 => divisor = (0+1)*(2^3)=8
        spi_mode_i = 2'b01;
 
        // ---- Apply Reset ----
        repeat(5) @(posedge PCLK);
        PRESET_n = 1;
        repeat(5) @(posedge PCLK);
 
        // ==================================================
        // TEST 1: SPI MODE 0 (CPOL=0, CPHA=0)
        // ==================================================
        $display("-------------------------------");
        $display("TEST 1: SPI Mode 0 (CPOL=0, CPHA=0)");
        $display("SPPR=0, SPR=2 => BaudRateDivisor = %0d", ((0+1)*(2**(2+1))));
        cpol_i    = 0;
        cpha_i    = 0;
        spi_mode_i = 2'b00;
        sppr_i    = 3'b000;
        spr_i     = 3'b010;
        ss_i      = 0;      // Assert SS (start transfer)
 
        // Run for enough cycles to see 8 SCLK toggles
        repeat(200) @(posedge PCLK);
        ss_i = 1;           // Deassert SS
        repeat(10) @(posedge PCLK);
 
        // ==================================================
        // TEST 2: SPI MODE 1 (CPOL=0, CPHA=1)
        // ==================================================
        $display("-------------------------------");
        $display("TEST 2: SPI Mode 1 (CPOL=0, CPHA=1)");
        cpol_i    = 0;
        cpha_i    = 1;
        spi_mode_i = 2'b01;
        sppr_i    = 3'b000;
        spr_i     = 3'b010;
        ss_i      = 0;
 
        repeat(200) @(posedge PCLK);
        ss_i = 1;
        repeat(10) @(posedge PCLK);
 
        // ==================================================
        // TEST 3: SPI MODE 2 (CPOL=1, CPHA=0)
        // ==================================================
        $display("-------------------------------");
        $display("TEST 3: SPI Mode 2 (CPOL=1, CPHA=0)");
        cpol_i    = 1;
        cpha_i    = 0;
        spi_mode_i = 2'b10;
        sppr_i    = 3'b000;
        spr_i     = 3'b010;
        ss_i      = 0;
 
        repeat(200) @(posedge PCLK);
        ss_i = 1;
        repeat(10) @(posedge PCLK);
 
        // ==================================================
        // TEST 4: SPI MODE 3 (CPOL=1, CPHA=1)
        // ==================================================
        $display("-------------------------------");
        $display("TEST 4: SPI Mode 3 (CPOL=1, CPHA=1)");
        cpol_i    = 1;
        cpha_i    = 1;
        spi_mode_i = 2'b11;
        sppr_i    = 3'b000;
        spr_i     = 3'b010;
        ss_i      = 0;
 
        repeat(200) @(posedge PCLK);
        ss_i = 1;
        repeat(10) @(posedge PCLK);
 
        // ==================================================
        // TEST 5: Different SPPR and SPR values
        // SPPR=1, SPR=1 => divisor = (1+1)*(2^2) = 8
        // ==================================================
        $display("-------------------------------");
        $display("TEST 5: SPPR=1, SPR=1 => Divisor=%0d", ((1+1)*(2**(1+1))));
        cpol_i    = 0;
        cpha_i    = 0;
        spi_mode_i = 2'b00;
        sppr_i    = 3'b001;
        spr_i     = 3'b001;
        ss_i      = 0;
 
        repeat(200) @(posedge PCLK);
        ss_i = 1;
        repeat(10) @(posedge PCLK);
 
        // ==================================================
        // TEST 6: SPISWAI mode (stop-in-wait)
        // ==================================================
        $display("-------------------------------");
        $display("TEST 6: SPISWAI mode test");
        cpol_i    = 0;
        cpha_i    = 0;
        sppr_i    = 3'b000;
        spr_i     = 3'b010;
        ss_i      = 0;
        spiswai_i = 0;
        repeat(50) @(posedge PCLK);
        spiswai_i = 1;   // Assert wait mode - should freeze clock
        repeat(20) @(posedge PCLK);
        spiswai_i = 0;   // Deassert - should resume
        repeat(100) @(posedge PCLK);
        ss_i = 1;
        repeat(10) @(posedge PCLK);
 
        // ==================================================
        // TEST 7: Reset during operation
        // ==================================================
        $display("-------------------------------");
        $display("TEST 7: Reset during active transfer");
        cpol_i    = 0;
        cpha_i    = 0;
        sppr_i    = 3'b000;
        spr_i     = 3'b010;
        ss_i      = 0;
        repeat(50) @(posedge PCLK);
        PRESET_n  = 0;   // Assert reset
        repeat(5)  @(posedge PCLK);
        PRESET_n  = 1;   // Deassert reset
        repeat(100) @(posedge PCLK);
        ss_i = 1;
        repeat(10) @(posedge PCLK);
 
        $display("-------------------------------");
        $display("All tests complete.");
        $display("BaudRateDivisor (final) = %0d", baudratedivisor_o);
        $stop;
    end
 
    // -------------------------------------------------------
    // Monitor: Print key events
    // -------------------------------------------------------
    initial begin
        $monitor("Time=%0t | sclk=%b | miso_pos=%b | miso_neg=%b | mosi_pos=%b | mosi_neg=%b | divisor=%0d",
                 $time, sclk_o, miso_receive_sclk_o, miso_receive_sclk0_o,
                 mosi_send_sclk_o, mosi_send_sclk0_o, baudratedivisor_o);
    end
 
endmodule