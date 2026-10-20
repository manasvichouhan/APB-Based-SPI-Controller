module SPI_Baud_gen(
    input  wire        PCLK,
    input  wire        PRESET_n,
    input  wire        spiswai_i,       // SPI Stop-in-Wait
    input  wire        cpol_i,          // Clock Polarity
    input  wire        cpha_i,          // Clock Phase
    input  wire        ss_i,            // Slave Select (active low)
    input  wire [2:0]  sppr_i,          // SPI Baud Rate Prescaler
    input  wire [2:0]  spr_i,           // SPI Baud Rate Divisor
    input  wire [1:0]  spi_mode_i,      // SPI Mode (Master/Slave config)

    output reg         sclk_o,                // SPI Clock output
    output reg         miso_receive_sclk_o,   // MISO sample clock (posedge)
    output reg         miso_receive_sclk0_o,  // MISO sample clock (negedge)
    output reg         mosi_send_sclk_o,      // MOSI shift clock (posedge)
    output reg         mosi_send_sclk0_o,     // MOSI shift clock (negedge)
    output wire [11:0] baudratedivisor_o       // Computed baud rate divisor
);

    // -------------------------------------------------------
    // Baud Rate Divisor Calculation
    // BaudRateDivisor = (SPPR + 1) * 2^(SPR + 1)
    // -------------------------------------------------------
    assign baudratedivisor_o = ((sppr_i + 3'd1) * (12'd2 << spr_i));

    // -------------------------------------------------------
    // Pre-SCLK idle state: CPOL determines idle level
    // -------------------------------------------------------
    wire pre_sclk_s;
    assign pre_sclk_s = cpol_i ? 1'b1 : 1'b0;

    // -------------------------------------------------------
    // Count Logic
    // -------------------------------------------------------
    reg [11:0] count_s;

    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            count_s <= 12'd0;
        end
        else if (ss_i || spiswai_i) begin
            // Reset counter when SS deasserted or wait mode
            count_s <= 12'd0;
        end
        else begin
            if (count_s >= baudratedivisor_o - 12'd1)
                count_s <= 12'd0;
            else
                count_s <= count_s + 12'd1;
        end
    end

    // -------------------------------------------------------
    // SCLK Generation
    // Toggle at half-period of baudratedivisor
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            sclk_o <= 1'b0;
        end
        else if (ss_i || spiswai_i) begin
            sclk_o <= pre_sclk_s;
        end
        else begin
            if (count_s == baudratedivisor_o / 2 - 12'd1)
                sclk_o <= ~sclk_o;
            else if (count_s == baudratedivisor_o - 12'd1)
                sclk_o <= ~sclk_o;
        end
    end

    // -------------------------------------------------------
    // MISO Receive SCLK (Posedge aligned)
    // Used when CPHA=0,CPOL=0 or CPHA=1,CPOL=1
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            miso_receive_sclk_o <= 1'b0;
        end
        else if (ss_i || spiswai_i) begin
            miso_receive_sclk_o <= 1'b0;
        end
        else begin
            // Assert one clock before rising edge of sclk
            if ((!cpha_i && !cpol_i) || (cpha_i && cpol_i)) begin
                if (sclk_o == 1'b0) begin
                    if (count_s == baudratedivisor_o / 2 - 12'd2)
                        miso_receive_sclk_o <= 1'b1;
                    else
                        miso_receive_sclk_o <= 1'b0;
                end
                else
                    miso_receive_sclk_o <= 1'b0;
            end
            else
                miso_receive_sclk_o <= 1'b0;
        end
    end

    // -------------------------------------------------------
    // MISO Receive SCLK0 (Negedge aligned)
    // Used when CPHA=1,CPOL=0 or CPHA=0,CPOL=1
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            miso_receive_sclk0_o <= 1'b0;
        end
        else if (ss_i || spiswai_i) begin
            miso_receive_sclk0_o <= 1'b0;
        end
        else begin
            if ((!cpha_i && cpol_i) || (cpha_i && !cpol_i)) begin
                if (sclk_o == 1'b1) begin
                    if (count_s == baudratedivisor_o / 2 - 12'd2)
                        miso_receive_sclk0_o <= 1'b1;
                    else
                        miso_receive_sclk0_o <= 1'b0;
                end
                else
                    miso_receive_sclk0_o <= 1'b0;
            end
            else
                miso_receive_sclk0_o <= 1'b0;
        end
    end

    // -------------------------------------------------------
    // MOSI Send SCLK (Posedge based shift)
    // CPHA=0,CPOL=0 or CPHA=1,CPOL=1
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            mosi_send_sclk_o <= 1'b0;
        end
        else if (ss_i || spiswai_i) begin
            mosi_send_sclk_o <= 1'b0;
        end
        else begin
            if ((!cpha_i && cpol_i) || (cpha_i && !cpol_i)) begin
                if (!sclk_o) begin
                    if (count_s == baudratedivisor_o / 2 - 2'b10)
                        mosi_send_sclk_o <= 1'b1;
                    else
                        mosi_send_sclk_o <= 1'b0;
                end
                else
                    mosi_send_sclk_o <= 1'b0;
            end
            else
                mosi_send_sclk_o <= 1'b0;
        end
    end

    // -------------------------------------------------------
    // MOSI Send SCLK0 (Negedge based shift)
    // CPHA=1,CPOL=0 or CPHA=0,CPOL=1
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            mosi_send_sclk0_o <= 1'b0;
        end
        else if (ss_i || spiswai_i) begin
            mosi_send_sclk0_o <= 1'b0;
        end
        else begin
            if ((!cpha_i && !cpol_i) || (cpha_i && cpol_i)) begin
                if (sclk_o) begin
                    if (count_s == baudratedivisor_o / 2 - 2'b10)
                        mosi_send_sclk0_o <= 1'b1;
                    else
                        mosi_send_sclk0_o <= 1'b0;
                end
                else
                    mosi_send_sclk0_o <= 1'b0;
            end
            else
                mosi_send_sclk0_o <= 1'b0;
        end
    end

endmodule
