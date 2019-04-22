
# dnnweaver2/hardware

This folder contains the following:
* file.list: contains the list of RTL files (verilog) for DnnWeaver2
* rtl/: contains all the RTL files

# Synthesis Instructions
### Create a Vivado project for DnnWeaver v2.0
* Create a new project using Vivado GUI. Let’s call it *dnnweaver-v2.0*
![proj-1](/hardware/dnnweaver-synth-pics/create-project-1.png)

* Select the appropriate board for your project. The rest of the instructions are specific to KCU1500 board using Vivado 2018.1. When synthesizing for a different FPGA board, the names of the IPs may change.
![proj-2](/hardware/dnnweaver-synth-pics/create-project-2.png)

* In this new project, add all the Verilog source files from the *hardware/rtl* folder

### Create a block design  with DDR4, PCIe, and DnnWeaver v2.0
* Create a new block design called *ku115*
* Drag and drop Xilinx's DDR1 IP from the board tab to the block design
* We will also use the DDR1 IP to create a clock for DnnWeaver. To do this, specify 150MHz as the frequency for addn_ui_clkout1 by double-clicking the IP and then specifying 150 MHz for Clock 1 in the *Advanced Clocking* tab.
* Drag and drop "FPGA Resetn” from the board tab into the block design. Note that the polarity of *FPGA Resetn* is active low, while DDR IP needs active high reset. Instantiate *Utility Vector Logic* IP by right-clicking the block design, selecting *add-ip*, and then selecting *Utility Vector Logic* IP. Set C_SIZE to 1 and C_Operation to *NOT*.  This will create a *not* gate. Connect the board resetn to the input of the not gate and connect the output to *sys_rst* of the DDR IP.
* The block design should now look like this:
![bd-ddr](/hardware/dnnweaver-synth-pics/block-design-ddr-only.png)

* Now drag and drop the PCIe IP from the board tab to the block design.
* Run block automation.
* Enable the “M_AXI_LITE” AXI port by right-clicking the PCIe IP and “PCIe: BARs” and enabling “PCIe to AXI Lite Master Interface” and setting the size to 4KB
* The block design should now look like this:
![bd-automation](/hardware/dnnweaver-synth-pics/block-automation.png)

* Right click block design and add module, search for *cl_wrapper*. This is the top-level module for DnnWeaver v2.0 RTL.
* Connect the addn_ui_clkout1 to cl_wrapper’s clk port
* Run connection automation  and connect the M_AXI_LITE of the xdma with pci_cl_ctrl
* Run connection automation  and connect the M_AXI of the xdma with pci_cl_data and DDR’s C0_DDR4_s_AXI
* Run connection automation  and connect the cl_ddr0-4 of the cl_wrapper with the DDR as well
* The final block design should now look like this:
![bd-final](/hardware/dnnweaver-synth-pics/final-block-design.png)
* Right-click the *ku115* block design in the *sources* tab and select *create HDL wrapper*.


You can now generate a bitfile to program your FPGA.

