// ============================================================
// Module : SPI_Slave_Select
// Description : Slave Select Control for APB-based SPI Controller
// Generates SS, TIP, and receive_data signals based on
// baud rate divisor and SPI mode
// ============================================================

module SPI_Slave_Select(
    input  wire        PCLK,
    input  wire        PRESET_n,
    input  wire        send_data_i,      // Trigger to start SPI transfer
    input  wire        mstr_i,           // Master mode select
    input  wire        spiswai_i,        // SPI Stop-in-Wait
    input  wire [1:0]  spi_mode_i,       // SPI Mode
    input  wire [11:0] baudratedivisor_i, // From Baud Rate Generator

    output reg         receive_data_o,   // Data received flag
    output reg         ss_o,             // Slave Select (active low)
    output wire        tip_o             // Transfer In Progress
);

    // -------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------
    reg  [15:0] count_s;     // Baud-based timing counter
    wire [15:0] target_s;    // Total count for 8-bit transfer (16 edges)
    reg         rcv_s;       // Receive indicator

    // -------------------------------------------------------
    // Target = 16 * (BaudRateDivisor / 2)
    // 8 bits => 16 clock edges, each edge = BaudRateDivisor/2 PCLK cycles
    // -------------------------------------------------------
    assign target_s = 16 * (baudratedivisor_i / 2);

    // -------------------------------------------------------
    // TIP = Transfer In Progress = ~ss_o
    // -------------------------------------------------------
    assign tip_o = ~ss_o;

    // -------------------------------------------------------
    // Main FSM: SS, Counter, RCV logic
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            ss_o           <= 1'b1;   // Deassert SS on reset
            count_s        <= 16'd0;
            rcv_s          <= 1'b0;
            receive_data_o <= 1'b0;
        end
        else if (spiswai_i) begin
            // Stop-in-wait: freeze everything
            ss_o           <= 1'b1;
            count_s        <= 16'd0;
            rcv_s          <= 1'b0;
            receive_data_o <= 1'b0;
        end
        else begin
            // ---- Idle: waiting for send_data trigger ----
            if (ss_o == 1'b1) begin
                receive_data_o <= 1'b0;
                rcv_s          <= 1'b0;
                count_s        <= 16'd0;

                if (send_data_i && mstr_i) begin
                    ss_o <= 1'b0;   // Assert SS — start transfer
                end
            end

            // ---- Transfer in progress ----
            else begin
                count_s <= count_s + 16'd1;

                // At midpoint: assert receive_data flag
                if (count_s == (target_s - 16'd1)) begin
                    rcv_s          <= 1'b1;
                    receive_data_o <= 1'b1;
                    ss_o           <= 1'b1;  // Deassert SS — transfer done
                    count_s        <= 16'd0;
                end
                else begin
                    rcv_s          <= 1'b0;
                    receive_data_o <= 1'b0;
                end
            end
        end
    end

endmodule
