`timescale 1ps/1ps
 
module SPI_Slave_Select_tb;
 
    // -------------------------------------------------------
    // DUT Inputs
    // -------------------------------------------------------
    reg        PCLK;
    reg        PRESET_n;
    reg        send_data_i;
    reg        mstr_i;
    reg        spiswai_i;
    reg [1:0]  spi_mode_i;
    reg [11:0] baudratedivisor_i;
 
    // -------------------------------------------------------
    // DUT Outputs
    // -------------------------------------------------------
    wire        receive_data_o;
    wire        ss_o;
    wire        tip_o;
 
    // -------------------------------------------------------
    // Loop variables (visible in waveform like screenshot)
    // -------------------------------------------------------
    integer i;
    integer j;
 
    // -------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------
    SPI_Slave_Select dut (
        .PCLK              (PCLK),
        .PRESET_n          (PRESET_n),
        .send_data_i       (send_data_i),
        .mstr_i            (mstr_i),
        .spiswai_i         (spiswai_i),
        .spi_mode_i        (spi_mode_i),
        .baudratedivisor_i (baudratedivisor_i),
        .receive_data_o    (receive_data_o),
        .ss_o              (ss_o),
        .tip_o             (tip_o)
    );
 
    // -------------------------------------------------------
    // Clock: 20ps period (50 GHz) — adjust to 20ns for 50MHz
    // -------------------------------------------------------
    initial PCLK = 0;
    always #10 PCLK = ~PCLK;
 
    // -------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------
    initial begin
        // ---- Initialize all inputs ----
        PRESET_n          = 0;
        send_data_i       = 0;
        mstr_i            = 1;       // Master mode
        spiswai_i         = 0;
        spi_mode_i        = 2'b00;   // Mode 0
        baudratedivisor_i = 12'd4;   // Small divisor for fast sim — matches screenshot value 4
 
        // ---- Apply Reset ----
        repeat(5) @(posedge PCLK);
        PRESET_n = 1;
        repeat(5) @(posedge PCLK);
 
        // ==================================================
        // TEST 1: Basic Transfer — Mode 0, BaudDiv=4
        // target = 16*(4/2) = 32 PCLK cycles
        // ==================================================
        $display("-------------------------------------------");
        $display("TEST 1: Basic SPI Transfer");
        $display("BaudRateDivisor = %0d, target = %0d cycles", baudratedivisor_i, 16*(baudratedivisor_i/2));
 
        send_data_i = 1;
        @(posedge PCLK);
        send_data_i = 0;
 
        // Wait for transfer to complete (ss_o goes high again)
        wait(ss_o == 1'b0);
        $display("Time=%0t : SS asserted — Transfer started", $time);
 
        wait(ss_o == 1'b1);
        $display("Time=%0t : SS deasserted — Transfer complete", $time);
 
        wait(receive_data_o == 1'b1);
        $display("Time=%0t : receive_data_o asserted", $time);
 
        repeat(10) @(posedge PCLK);
 
        // ==================================================
        // TEST 2: Back-to-back transfers
        // ==================================================
        $display("-------------------------------------------");
        $display("TEST 2: Back-to-back transfers");
 
        for (i = 0; i < 3; i = i + 1) begin
            send_data_i = 1;
            @(posedge PCLK);
            send_data_i = 0;
 
            wait(ss_o == 1'b0);
            wait(ss_o == 1'b1);
            $display("Time=%0t : Transfer %0d complete", $time, i+1);
            repeat(5) @(posedge PCLK);
        end
 
        // ==================================================
        // TEST 3: Different BaudRateDivisor = 8
        // target = 16*(8/2) = 64 cycles
        // ==================================================
        $display("-------------------------------------------");
        $display("TEST 3: BaudRateDivisor = 8");
        baudratedivisor_i = 12'd8;
        $display("New target = %0d cycles", 16*(8/2));
 
        send_data_i = 1;
        @(posedge PCLK);
        send_data_i = 0;
 
        wait(ss_o == 1'b0);
        wait(ss_o == 1'b1);
        $display("Time=%0t : Transfer complete with BaudDiv=8", $time);
        repeat(10) @(posedge PCLK);
 
        // ==================================================
        // TEST 4: SPISWAI — Stop in Wait mode
        // ==================================================
        $display("-------------------------------------------");
        $display("TEST 4: SPISWAI Stop-in-Wait test");
        baudratedivisor_i = 12'd4;
 
        send_data_i = 1;
        @(posedge PCLK);
        send_data_i = 0;
 
        wait(ss_o == 1'b0);
        repeat(5) @(posedge PCLK);
 
        // Assert wait during transfer
        spiswai_i = 1;
        $display("Time=%0t : SPISWAI asserted — freezing transfer", $time);
        repeat(10) @(posedge PCLK);
 
        // Deassert wait
        spiswai_i = 0;
        $display("Time=%0t : SPISWAI deasserted — resuming", $time);
        repeat(5) @(posedge PCLK);
 
        // Start new transfer after resume
        send_data_i = 1;
        @(posedge PCLK);
        send_data_i = 0;
 
        wait(ss_o == 1'b0);
        wait(ss_o == 1'b1);
        $display("Time=%0t : Transfer complete after SPISWAI", $time);
        repeat(10) @(posedge PCLK);
 
        // ==================================================
        // TEST 5: Reset during transfer
        // ==================================================
        $display("-------------------------------------------");
        $display("TEST 5: Reset during active transfer");
        baudratedivisor_i = 12'd4;
 
        send_data_i = 1;
        @(posedge PCLK);
        send_data_i = 0;
 
        wait(ss_o == 1'b0);
        repeat(5) @(posedge PCLK);
 
        // Mid-transfer reset
        PRESET_n = 0;
        $display("Time=%0t : Reset asserted mid-transfer", $time);
        repeat(5) @(posedge PCLK);
        PRESET_n = 1;
        $display("Time=%0t : Reset deasserted", $time);
        repeat(10) @(posedge PCLK);
 
        // ==================================================
        // TEST 6: Slave mode (mstr_i = 0) — SS should NOT assert
        // ==================================================
        $display("-------------------------------------------");
        $display("TEST 6: Slave mode — SS should not assert");
        mstr_i = 0;
 
        send_data_i = 1;
        @(posedge PCLK);
        send_data_i = 0;
 
        repeat(20) @(posedge PCLK);
        $display("Time=%0t : ss_o = %b (expected 1 in slave mode)", $time, ss_o);
 
        mstr_i = 1; // Restore master mode
 
        // ==================================================
        // TEST 7: SPI Mode 1, 2, 3 — verify mode switching
        // ==================================================
        $display("-------------------------------------------");
        $display("TEST 7: SPI Mode switching");
 
        for (j = 0; j < 4; j = j + 1) begin
            spi_mode_i = j[1:0];
            baudratedivisor_i = 12'd4;
 
            send_data_i = 1;
            @(posedge PCLK);
            send_data_i = 0;
 
            wait(ss_o == 1'b0);
            wait(ss_o == 1'b1);
            $display("Time=%0t : Mode %0d transfer complete", $time, j);
            repeat(10) @(posedge PCLK);
        end
 
        $display("-------------------------------------------");
        $display("All tests complete!");
        $stop;
    end
 
    // -------------------------------------------------------
    // Monitor
    // -------------------------------------------------------
    initial begin
        $monitor("Time=%0t | ss_o=%b | tip_o=%b | receive_data_o=%b | count=%0d",
                 $time, ss_o, tip_o, receive_data_o, dut.count_s);
    end
 
endmodule