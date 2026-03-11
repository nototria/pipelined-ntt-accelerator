VERILATOR ?= verilator
ROOT      := $(abspath .)

TOP     ?= PipelineNTT_top
MODE    ?= dit
INPUT   ?=
CYCLES  ?=

TOP_V   := $(ROOT)/PipelineNTT_top.v
TB_CPP  := $(ROOT)/testbench.cpp
MDIR    := obj_dir/$(MODE)
BIN     := $(MDIR)/V$(TOP)

OPENNTT_REL_SRCS := \
	NTT-RTL-gen/rtl/ct_bf_openntt.sv \
	NTT-RTL-gen/rtl/gs_bf_openntt.sv \
	NTT-RTL-gen/rtl/OpenNTT/intmul_pkg.sv \
	NTT-RTL-gen/rtl/OpenNTT/shiftreg.sv \
	NTT-RTL-gen/rtl/OpenNTT/divby2.sv \
	NTT-RTL-gen/rtl/OpenNTT/modadd.sv \
	NTT-RTL-gen/rtl/OpenNTT/modsub.sv \
	NTT-RTL-gen/rtl/OpenNTT/modred.sv \
	NTT-RTL-gen/rtl/OpenNTT/intmul.sv \
	NTT-RTL-gen/rtl/OpenNTT/btf_addsub.sv \
	NTT-RTL-gen/rtl/OpenNTT/btf_modmul.sv \
	NTT-RTL-gen/rtl/OpenNTT/btf_uni.sv \
	NTT-RTL-gen/rtl/OpenNTT/modred_wl_mont/int_mult_add_p0.sv \
	NTT-RTL-gen/rtl/OpenNTT/modred_wl_mont/wlmont.sv \
	NTT-RTL-gen/rtl/OpenNTT/modred_wl_mont/wlmont_sub_p0.sv
OPENNTT_SRCS := $(addprefix $(ROOT)/,$(OPENNTT_REL_SRCS))

VERILATOR_FLAGS := \
	-j 0 \
	--cc --exe --build \
	--default-language 1800-2017 \
	-Wno-fatal \
	-Wno-TIMESCALEMOD \
	-Wno-WIDTHEXPAND \
	--Mdir $(MDIR) \
	-top-module $(TOP)

ifeq ($(MODE),dit)
MODE_DEFINE :=
else ifeq ($(MODE),dif)
MODE_DEFINE := -DPIPELINE_NTT_USE_DIF
else
$(error MODE must be "dit" or "dif")
endif

RUN_ARGS :=
ifneq ($(strip $(INPUT)),)
RUN_ARGS += $(INPUT)
endif
ifneq ($(strip $(CYCLES)),)
RUN_ARGS += $(CYCLES)
endif

.PHONY: all build run clean help

all: run

build: $(BIN)

$(BIN): $(TOP_V) $(TB_CPP) $(OPENNTT_SRCS)
	$(VERILATOR) $(VERILATOR_FLAGS) $(MODE_DEFINE) $(TOP_V) $(TB_CPP) $(OPENNTT_SRCS)

run: $(BIN)
	./$(BIN) $(RUN_ARGS)

clean:
	rm -rf obj_dir

help:
	@echo "Targets:"
	@echo "  make build MODE=dit|dif"
	@echo "  make run MODE=dit|dif [INPUT=path/to/input.hex] [CYCLES=36]"
	@echo "  make clean"
