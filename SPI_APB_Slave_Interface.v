// ============================================================
// Module      : SPI_APB_Slave_Interface
// Project     : APB-Based SPI
// Tool        : Quartus 18.1 / ModelSim
// Description : APB Slave Interface for SPI controller.
//               Implements APB protocol with internal control
//               registers (CR1, CR2, SR, DR) and drives SPI
//               configuration outputs.
//
// Register Map (PADDR_i[2:0]):
//   3'b000 -> SPI_CR1  : [mstr, cpol, cpha, lsbfe, spe, spiswai, ssoe]
//   3'b001 -> SPI_CR2  : [reserved / cr2_mask bits]
//   3'b010 -> SPI_BR   : {spiswai_o[2:0], sppr[2:0], spr[2:0]}
//   3'b011 -> SPI_SR   : Status register (tip, receive_data)
//   3'b100 -> SPI_DR   : Data register (write=TX, read=RX)
// ============================================================

module SPI_APB_Slave_Interface (
    // APB global signals
    input  wire        PCLK,
    input  wire        PRESET_n,

    // APB slave signals
    input  wire [2:0]  PADDR_i,
    input  wire        PWRITE_i,
    input  wire        PSEL_i,
    input  wire        PENABLE_i,
    input  wire [7:0]  PWDATA_i,

    // SPI status inputs
    input  wire        ss_i,
    input  wire [7:0]  miso_data_i,
    input  wire        receive_data_i,
    input  wire        tip_i,

    // APB slave outputs
    output reg  [7:0]  PRDATA_o,
    output reg         PREADY_o,
    output reg         PSLVERR_o,

    // SPI configuration outputs
    output reg         mstr_o,
    output reg         cpol_o,
    output reg         cpha_o,
    output reg         lsbfe_o,
    output reg  [2:0]  spiswai_o,
    output reg  [2:0]  sppr_o,
    output reg  [2:0]  spr_o,
    output reg         spi_interrupt_request_o,

    // Data path outputs
    output reg         send_data_o,
    output reg  [7:0]  mosi_data_o,
    output reg  [1:0]  spi_mode_o
);

    // -------------------------------------------------------
    // Internal Registers
    // -------------------------------------------------------
    reg [7:0]  SPI_CR1;      // Control Register 1
    reg [7:0]  SPI_CR2;      // Control Register 2
    reg [7:0]  SPI_BR;       // Baud Rate Register
    reg [7:0]  SPI_SR;       // Status Register
    reg [7:0]  SPI_DR;       // Data Register (TX)

    // CR masks
    localparam CR1_MASK = 8'hFF;
    localparam CR2_MASK = 8'hFF;  // adjust as per spec
    wire [7:0] cr2_mask = 8'hFF;

    // Write enable: APB write phase
    wire wr_enb = PSEL_i & PENABLE_i & PWRITE_i;
    // Read enable
    wire rd_enb = PSEL_i & PENABLE_i & ~PWRITE_i;

    // -------------------------------------------------------
    // PREADY_o / PSLVERR_o
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            PREADY_o  <= 1'b0;
            PSLVERR_o <= 1'b0;
        end
        else begin
            PREADY_o  <= PSEL_i & PENABLE_i;   // 1-cycle ready
            PSLVERR_o <= 1'b0;                  // no error
        end
    end

    // -------------------------------------------------------
    // SPI_CR1 Write Logic
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n)
            SPI_CR1 <= 8'h00;
        else if (wr_enb) begin
            if (PADDR_i == 3'b000)
                SPI_CR1 <= PWDATA_i & CR1_MASK;
            else
                SPI_CR1 <= SPI_CR1;
        end
    end

    // -------------------------------------------------------
    // SPI_CR2 Write Logic
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n)
            SPI_CR2 <= 8'h00;
        else if (wr_enb) begin
            if (PADDR_i == 3'b001)
                SPI_CR2 <= PWDATA_i & cr2_mask;
            else
                SPI_CR2 <= SPI_CR2;
        end
    end

    // -------------------------------------------------------
    // SPI_BR (Baud Rate) Write Logic
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n)
            SPI_BR <= 8'h00;
        else if (wr_enb) begin
            if (PADDR_i == 3'b010)
                SPI_BR <= PWDATA_i;
            else
                SPI_BR <= SPI_BR;
        end
    end

    // -------------------------------------------------------
    // SPI_SR (Status Register) – read-only fields
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n)
            SPI_SR <= 8'h00;
        else begin
            SPI_SR[7] <= receive_data_i;  // SPIF  - transfer complete
            SPI_SR[4] <= tip_i;           // MODF  - mode fault / TIP
            SPI_SR[0] <= ss_i;            // SS status
            // Other bits reserved
        end
    end

    // -------------------------------------------------------
    // SPI_DR (Data Register) Write Logic  → triggers TX
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            SPI_DR      <= 8'h00;
            send_data_o <= 1'b0;
            mosi_data_o <= 8'h00;
        end
        else begin
            send_data_o <= 1'b0;          // default pulse-low
            if (wr_enb && (PADDR_i == 3'b100)) begin
                SPI_DR      <= PWDATA_i;
                mosi_data_o <= PWDATA_i;
                send_data_o <= 1'b1;      // one-cycle load pulse
            end
        end
    end

    // -------------------------------------------------------
    // PRDATA_o – APB Read Mux
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n)
            PRDATA_o <= 8'h00;
        else if (rd_enb) begin
            case (PADDR_i)
                3'b000: PRDATA_o <= SPI_CR1;
                3'b001: PRDATA_o <= SPI_CR2;
                3'b010: PRDATA_o <= SPI_BR;
                3'b011: PRDATA_o <= SPI_SR;
                3'b100: PRDATA_o <= miso_data_i;   // read RX data
                default: PRDATA_o <= 8'hXX;
            endcase
        end
    end

    // -------------------------------------------------------
    // SPI Configuration outputs decoded from CR1
    // CR1[7] = mstr   CR1[6] = cpol   CR1[5] = cpha
    // CR1[4] = lsbfe  CR1[1:0] = spi_mode
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            mstr_o   <= 1'b0;
            cpol_o   <= 1'b0;
            cpha_o   <= 1'b0;
            lsbfe_o  <= 1'b0;
            spi_mode_o <= 2'b00;
        end
        else begin
            mstr_o     <= SPI_CR1[7];
            cpol_o     <= SPI_CR1[6];
            cpha_o     <= SPI_CR1[5];
            lsbfe_o    <= SPI_CR1[4];
            spi_mode_o <= SPI_CR1[1:0];
        end
    end

    // -------------------------------------------------------
    // Baud Rate outputs decoded from SPI_BR
    // SPI_BR[7:5] = spiswai  SPI_BR[4:2] = sppr  SPI_BR[1:0]+ext = spr
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            spiswai_o <= 3'b000;
            sppr_o    <= 3'b000;
            spr_o     <= 3'b000;
        end
        else begin
            spiswai_o <= SPI_BR[7:5];
            sppr_o    <= SPI_BR[4:2];
            spr_o     <= SPI_BR[2:0];
        end
    end

    // -------------------------------------------------------
    // Interrupt request: fires when transfer complete (SPIF)
    // -------------------------------------------------------
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n)
            spi_interrupt_request_o <= 1'b0;
        else
            spi_interrupt_request_o <= SPI_SR[7] & SPI_CR1[3]; // SPIF & SPIE
    end

endmodule