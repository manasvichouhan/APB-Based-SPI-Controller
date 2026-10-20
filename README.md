# APB-Based-SPI-Controller

## Project Overview
Designed and simulated an SPI controller using the Advanced Peripheral Bus (APB) interface.

## Objectives
- Interface APB communication with SPI serial communication.
- Implement control logic for SPI data transfer.
- Verify functionality through simulation.

## Tools Used
- Verilog HDL
- ModelSim
- Intel Quartus Prime

## Project Files
- `APB_SPI_Top.v` – Top-level module
- `SPI_APB_Slave_Interface.v` – APB interface logic
- `SPI_Baud_gen.v` – SPI clock generation
- `SPI_Shift_register.v` – Serial data shifting
- `SPI_Slave_Select.v` – Slave selection logic
- `APB_SPI_Top_TB.v` – Testbench

## Results
<img width="1907" height="712" alt="shift1" src="https://github.com/user-attachments/assets/0cbd31e0-5d6e-40f0-9d88-08456d9124cb" />
<img width="1902" height="737" alt="slaveselect1" src="https://github.com/user-attachments/assets/f974838c-19ae-4abf-800b-a5429e9234d3" />
<img width="1797" height="747" alt="baud1" src="https://github.com/user-attachments/assets/447b7782-82f5-4a43-af15-7fcb25765db4" />
<img width="1887" height="792" alt="spi_top1" src="https://github.com/user-attachments/assets/24e672b0-64d1-4c45-9c9e-6add2ba9b273" />
<img width="1907" height="877" alt="slavewave" src="https://github.com/user-attachments/assets/f64f7f44-49d6-493e-a852-2076d99e0582" />

<img width="1887" height="881" alt="syntheses" src="https://github.com/user-attachments/assets/98bd2cfa-16a6-4673-8449-6a120b004258" />



## Author
Manasvi Singh Chouhan
