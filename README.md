PCI-Express Core with Bus Master (Work In Progress)
-----------------------------
[> Directory Structure
 /boards/     Top-level design files, constraint files and Makefiles
              for supported FPGA boards.
 /doc/        Documentation.
 /software/   Software.

[> Support Boards
1- Lattice ECP3 Versakit

[> Building tools
You will need:
 - Lattice diamond 2.0/2.1/2.2

[> How to build
1- cd boards/ecp3versa/synthesis
2- make


[> Memo ]
available BAR2 range:
64MB -> xpc	(0xfc00000c)
1GB  -> fujitsu	(0xc000000c)

