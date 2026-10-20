// ============================================================
// APB_SPI_Top.v
// Top-level module integrating all SPI submodules
// Compatible with ModelSim & Quartus 18.1
// ============================================================

module APB_SPI_Top (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire        miso,
    input  wire [2:0]  PADDR,
    input  wire [7:0]  PWDATA,
    output wire [7:0]  PRDATA,
    output wire        PREADY,
    output wire        PSLVERR,
    output wire        sclk,
    output wire        ss,
    output wire        mosi,
    output wire        spi_interrupt_request
);

    // -------------------------------------------------------
    // Internal wires — names match submodule port suffixes
    // -------------------------------------------------------
    wire [2:0]  spr_w, sppr_w;
    wire [2:0]  spiswai_w;        // SPI_APB_Slave_Interface drives [2:0]
    wire [1:0]  spi_mode_w;
    wire [11:0] baudratedivisor_w;
    wire [7:0]  data_mosi_w, data_miso_w;
    wire        cpol_w, cpha_w, tip_w, mstr_w;
    wire        send_data_w, receive_data_w, lsbfe_w;
    wire        miso_receive_sclk_w, miso_receive_sclk0_w;
    wire        mosi_send_sclk_w,  mosi_send_sclk0_w;

    // spiswai to baud-gen is 1-bit (OR of the 3-bit bus)
    wire        spiswai_1b = |spiswai_w;

    // -------------------------------------------------------
    // A: SPI_Baud_gen
    // -------------------------------------------------------
    SPI_Baud_gen A1 (
        .PCLK                  (PCLK),
        .PRESET_n              (PRESETn),
        .spiswai_i             (spiswai_1b),
        .cpol_i                (cpol_w),
        .cpha_i                (cpha_w),
        .ss_i                  (ss),
        .sppr_i                (sppr_w),
        .spr_i                 (spr_w),
        .spi_mode_i            (spi_mode_w),
        .sclk_o                (sclk),
        .miso_receive_sclk_o   (miso_receive_sclk_w),
        .miso_receive_sclk0_o  (miso_receive_sclk0_w),
        .mosi_send_sclk_o      (mosi_send_sclk_w),
        .mosi_send_sclk0_o     (mosi_send_sclk0_w),
        .baudratedivisor_o     (baudratedivisor_w)
    );

    // -------------------------------------------------------
    // B: SPI_Slave_Select
    // -------------------------------------------------------
    SPI_Slave_Select B1 (
        .PCLK                  (PCLK),
        .PRESET_n              (PRESETn),
        .send_data_i           (send_data_w),
        .mstr_i                (mstr_w),
        .spiswai_i             (spiswai_1b),
        .spi_mode_i            (spi_mode_w),
        .baudratedivisor_i     (baudratedivisor_w),
        .receive_data_o        (receive_data_w),
        .ss_o                  (ss),
        .tip_o                 (tip_w)
    );

    // -------------------------------------------------------
    // C: SPI_Shift_register
    // -------------------------------------------------------
    SPI_Shift_register C1 (
        .PCLK                  (PCLK),
        .PRESET_n              (PRESETn),
        .ss_i                  (ss),
        .send_data_i           (send_data_w),
        .lsbfe_i               (lsbfe_w),
        .cpha_i                (cpha_w),
        .cpol_i                (cpol_w),
        .miso_receive_sclk_i   (miso_receive_sclk_w),
        .miso_receive_sclk0_i  (miso_receive_sclk0_w),
        .mosi_send_sclk_i      (mosi_send_sclk_w),
        .mosi_send_sclk0_i     (mosi_send_sclk0_w),
        .data_mosi_i           (data_mosi_w),
        .miso_i                (miso),
        .receive_data_i        (receive_data_w),
        .mosi_o                (mosi),
        .data_miso_o           (data_miso_w)
    );

    // -------------------------------------------------------
    // D: SPI_APB_Slave_Interface
    // -------------------------------------------------------
    SPI_APB_Slave_Interface D1 (
        .PCLK                    (PCLK),
        .PRESET_n                (PRESETn),
        .PADDR_i                 (PADDR),
        .PWRITE_i                (PWRITE),
        .PSEL_i                  (PSEL),
        .PENABLE_i               (PENABLE),
        .PWDATA_i                (PWDATA),
        .ss_i                    (ss),
        .miso_data_i             (data_miso_w),
        .receive_data_i          (receive_data_w),
        .tip_i                   (tip_w),
        .PRDATA_o                (PRDATA),
        .PREADY_o                (PREADY),
        .PSLVERR_o               (PSLVERR),
        .mstr_o                  (mstr_w),
        .cpol_o                  (cpol_w),
        .cpha_o                  (cpha_w),
        .lsbfe_o                 (lsbfe_w),
        .spiswai_o               (spiswai_w),
        .sppr_o                  (sppr_w),
        .spr_o                   (spr_w),
        .spi_interrupt_request_o (spi_interrupt_request),
        .send_data_o             (send_data_w),
        .mosi_data_o             (data_mosi_w),
        .spi_mode_o              (spi_mode_w)
    );

endmodule