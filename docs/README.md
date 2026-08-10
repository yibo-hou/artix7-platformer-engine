# Documentation guide

This directory separates design intent, implementation reference, and
board-operation notes.

| Document | Purpose | Primary audience |
| --- | --- | --- |
| `architecture.md` | Explains the MicroBlaze/RTL partition, render and frame-buffer dataflow, clocks, resets, and startup sequence | FPGA and embedded engineers reviewing the design |
| `module_description.md` | Maps checked-in RTL, Xilinx IP, simulation, and software files to their responsibilities | Engineers navigating the source tree |
| `hardware_interfaces.md` | Records board pins, external protocols, timing, memory map, AXI addresses, and debug interfaces | Engineers rebuilding or adapting the hardware |
| `bringup.md` | Gives board-programming steps, expected UART/LED behavior, diagnostics, and current hardware configuration notes | Engineers running the design on the CF7A100B board |

Start with the root `README.md`, then read `architecture.md`. The other files
are references for implementation and hardware operation rather than a required
linear tutorial.
