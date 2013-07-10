SOURCES=$(wildcard *.v) \
	$(wildcard ../../../cores/gmii2fifo9/rtl/*.v) \
	$(wildcard ../rtl/ecp3/pciedma.v) \
	$(wildcard ../rtl/ecp3/server.v) \
	$(wildcard ../rtl/ecp3/pcie_tlp.v)

#all: cversim
all: tlp_data.hex phy_data.hex isim udpclient

gtk: all
	gtkwave test.vcd

isim: tb_system
	./tb_system

cversim: $(SOURCES)
	cver $(SOURCES)

clean:
	rm -f tb_system verilog.log test.vcd

tb_system: $(SOURCES)
	iverilog -o tb_system $(SOURCES)

udpclient: udpclient.c
	gcc -o udpclient udpclient.c

.PHONY: clean isim cversim gtk
