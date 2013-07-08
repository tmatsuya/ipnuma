SOURCES=tb_system.v \
	$(wildcard ../rtl/ecp3/pciedma.v) \
	$(wildcard ../rtl/ecp3/pcie_tlp.v)

#all: cversim
all: tlp_data.hex master_data.hex isim

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

.PHONY: clean isim cversim gtk
