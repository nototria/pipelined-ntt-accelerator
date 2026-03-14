VERILATOR ?= verilator
ROOT      := $(abspath .)
ROOT_PARENT := $(abspath $(ROOT)/..)

TOP     ?= PipelineNTT_top
MODE    ?= dit
INPUT   ?=
CYCLES  ?=

TOP_V   := $(ROOT)/PipelineNTT_top.v
TB_CPP  := $(ROOT)/testbench.cpp
MDIR    := obj_dir/$(MODE)
BIN     := $(MDIR)/V$(TOP)

MODMUL_DIR  := $(ROOT)/modmul
MODMUL_MDIR := obj_dir/modmul
MODMUL_TB   := $(MODMUL_DIR)/tb_modmul_unit.sv
MODMUL_BIN  := $(MODMUL_MDIR)/Vtb_modmul_unit
MODMUL_SRCS := \
	$(MODMUL_DIR)/modmul_unit.v \
	$(MODMUL_DIR)/multiply_unit.v \
	$(MODMUL_DIR)/csa_tree_3to2.sv \
	$(MODMUL_DIR)/openNTT/intmul_pkg.sv \
	$(MODMUL_DIR)/openNTT/intmul.sv \
	$(MODMUL_DIR)/openNTT/modred.sv \
	$(MODMUL_DIR)/openNTT/shiftreg.sv \
	$(MODMUL_DIR)/openNTT/modred_wl_mont/int_mult_add_p0.sv \
	$(MODMUL_DIR)/openNTT/modred_wl_mont/wlmont_sub_p0.sv \
	$(MODMUL_DIR)/openNTT/modred_wl_mont/wlmont.sv

NTT_SUBMODULE_ROOT := $(ROOT)/NTT-RTL-gen
NTT_SIBLING_ROOT   := $(ROOT_PARENT)/NTT-RTL-gen

ifneq ($(wildcard $(NTT_SUBMODULE_ROOT)/rtl/ct_bf_openntt.sv),)
NTT_ROOT := $(NTT_SUBMODULE_ROOT)
else ifneq ($(wildcard $(NTT_SIBLING_ROOT)/rtl/ct_bf_openntt.sv),)
NTT_ROOT := $(NTT_SIBLING_ROOT)
else
$(error NTT-RTL-gen not found. Initialize submodule with "git submodule update --init --recursive", or place repo at ../NTT-RTL-gen)
endif

NTT_BASE := $(abspath $(NTT_ROOT)/..)

OPENNTT_REL_SRCS := \
	rtl/ct_bf_openntt.sv \
	rtl/gs_bf_openntt.sv \
	rtl/OpenNTT/intmul_pkg.sv \
	rtl/OpenNTT/shiftreg.sv \
	rtl/OpenNTT/divby2.sv \
	rtl/OpenNTT/modadd.sv \
	rtl/OpenNTT/modsub.sv \
	rtl/OpenNTT/modred.sv \
	rtl/OpenNTT/intmul.sv \
	rtl/OpenNTT/btf_addsub.sv \
	rtl/OpenNTT/btf_modmul.sv \
	rtl/OpenNTT/btf_uni.sv \
	rtl/OpenNTT/modred_wl_mont/int_mult_add_p0.sv \
	rtl/OpenNTT/modred_wl_mont/wlmont.sv \
	rtl/OpenNTT/modred_wl_mont/wlmont_sub_p0.sv
OPENNTT_SRCS := $(addprefix $(NTT_ROOT)/,$(OPENNTT_REL_SRCS))

GEN_NTT_SRCS := \
	$(NTT_ROOT)/rtl-gen/dit_ntt.v \
	$(NTT_ROOT)/rtl-gen/dif_ntt.v

VERILATOR_FLAGS := \
	-j 0 \
	--cc --exe --build \
	--default-language 1800-2017 \
	-I$(NTT_BASE) \
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

.PHONY: all build run modmul-build modmul-test clean help

all: run

build: $(BIN)

$(GEN_NTT_SRCS):
	$(MAKE) -C $(NTT_ROOT) rtl-gen/dit_ntt.v rtl-gen/dif_ntt.v

$(MDIR):
	mkdir -p $@

$(BIN): $(TOP_V) $(TB_CPP) $(OPENNTT_SRCS) $(GEN_NTT_SRCS) | $(MDIR)
	$(VERILATOR) $(VERILATOR_FLAGS) $(MODE_DEFINE) $(TOP_V) $(TB_CPP) $(OPENNTT_SRCS)

run: $(BIN)
	./$(BIN) $(RUN_ARGS)

modmul-build: $(MODMUL_BIN)

$(MODMUL_MDIR):
	mkdir -p $@

$(MODMUL_BIN): $(MODMUL_TB) $(MODMUL_SRCS) | $(MODMUL_MDIR)
	$(VERILATOR) \
		-j 0 \
		--binary \
		--default-language 1800-2017 \
		-Wno-fatal \
		-Wno-WIDTHEXPAND \
		-Wno-WIDTHTRUNC \
		--Mdir $(MODMUL_MDIR) \
		-top-module tb_modmul_unit \
		$(MODMUL_TB) \
		$(MODMUL_SRCS)

modmul-test: modmul-build
	./$(MODMUL_BIN)

clean:
	rm -rf obj_dir

help:
	@echo "Targets:"
	@echo "  make build MODE=dit|dif"
	@echo "  make run MODE=dit|dif [INPUT=path/to/input.hex] [CYCLES=36]"
	@echo "  make modmul-test"
	@echo "  make clean"
