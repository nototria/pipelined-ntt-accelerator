VERILATOR ?= verilator
ROOT      := $(abspath .)
ROOT_PARENT := $(abspath $(ROOT)/..)

TOP := PipelineNTT_top

PIPELINE_TB   := $(ROOT)/tb_PipelineNTT_top.sv
PIPELINE_MDIR := obj_dir/pipeline
PIPELINE_BIN  := $(PIPELINE_MDIR)/Vtb_PipelineNTT_top

TOP_V := $(ROOT)/PipelineNTT_top.v

MODMUL_DIR  := $(ROOT)/modmul
MODMUL_MDIR := obj_dir/modmul
MODMUL_TB   := $(MODMUL_DIR)/tb_ModmulUnit.sv
MODMUL_BIN  := $(MODMUL_MDIR)/Vtb_ModmulUnit
MODMUL_SRCS := \
	$(MODMUL_DIR)/ModmulUnit.v \
	$(MODMUL_DIR)/MultiplyUnit.v \
	$(MODMUL_DIR)/csa_tree_3to2.sv \
	$(MODMUL_DIR)/openNTT/intmul_pkg.sv \
	$(MODMUL_DIR)/openNTT/intmul.sv \
	$(MODMUL_DIR)/openNTT/modred.sv \
	$(MODMUL_DIR)/openNTT/shiftreg.sv \
	$(MODMUL_DIR)/openNTT/modred_wl_mont/int_mult_add_p0.sv \
	$(MODMUL_DIR)/openNTT/modred_wl_mont/wlmont_sub_p0.sv \
	$(MODMUL_DIR)/openNTT/modred_wl_mont/wlmont.sv

TRANSPOSE_DIR  := $(ROOT)/transpose
TRANSPOSE_MDIR := obj_dir/transpose
TRANSPOSE_TB   := $(TRANSPOSE_DIR)/tb_TransposeUnit.sv
TRANSPOSE_BIN  := $(TRANSPOSE_MDIR)/Vtb_TransposeUnit
TRANSPOSE_SRCS := \
	$(TRANSPOSE_DIR)/TransposeUnit.v \
	$(TRANSPOSE_DIR)/QuadrantSwap.v

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
	rtl/OpenNTT/csa_3to2.sv \
	rtl/OpenNTT/csa_6to3.sv \
	rtl/OpenNTT/csa_tree_3to2.sv \
	rtl/OpenNTT/csa_tree_6to3.sv \
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

PIPELINE_SRCS := \
	$(PIPELINE_TB) \
	$(TOP_V) \
	$(MODMUL_DIR)/ModmulUnit.v \
	$(MODMUL_DIR)/MultiplyUnit.v \
	$(TRANSPOSE_DIR)/TransposeUnit.v \
	$(TRANSPOSE_DIR)/QuadrantSwap.v \
	$(GEN_NTT_SRCS) \
	$(OPENNTT_SRCS)

.PHONY: all build run pipeline-build pipeline-test modmul-build modmul-test transpose-build transpose-test clean help

all: pipeline-test

build: pipeline-build

run: pipeline-test

$(GEN_NTT_SRCS):
	$(MAKE) -C $(NTT_ROOT) rtl-gen/dit_ntt.v rtl-gen/dif_ntt.v

$(PIPELINE_MDIR):
	mkdir -p $@

$(PIPELINE_BIN): $(PIPELINE_SRCS) | $(PIPELINE_MDIR)
	$(VERILATOR) \
		-j 0 \
		--binary \
		--default-language 1800-2017 \
		-I$(NTT_BASE) \
		-Wno-fatal \
		-Wno-TIMESCALEMOD \
		-Wno-WIDTHEXPAND \
		-Wno-WIDTHTRUNC \
		--Mdir $(PIPELINE_MDIR) \
		-top-module tb_PipelineNTT_top \
		$(PIPELINE_SRCS)

pipeline-build: $(PIPELINE_BIN)

pipeline-test: pipeline-build
	./$(PIPELINE_BIN)

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
		-top-module tb_ModmulUnit \
		$(MODMUL_TB) \
		$(MODMUL_SRCS)

modmul-test: modmul-build
	./$(MODMUL_BIN)

transpose-build: $(TRANSPOSE_BIN)

$(TRANSPOSE_MDIR):
	mkdir -p $@

$(TRANSPOSE_BIN): $(TRANSPOSE_TB) $(TRANSPOSE_SRCS) | $(TRANSPOSE_MDIR)
	$(VERILATOR) \
		-j 0 \
		--binary \
		--default-language 1800-2017 \
		-Wno-fatal \
		-Wno-WIDTHEXPAND \
		-Wno-WIDTHTRUNC \
		--Mdir $(TRANSPOSE_MDIR) \
		-top-module tb_TransposeUnit \
		$(TRANSPOSE_TB) \
		$(TRANSPOSE_SRCS)

transpose-test: transpose-build
	./$(TRANSPOSE_BIN)

clean:
	rm -rf obj_dir

help:
	@echo "Targets:"
	@echo "  make build           # build pipeline top testbench"
	@echo "  make run             # build and run pipeline top testbench"
	@echo "  make pipeline-test   # run tb_PipelineNTT_top"
	@echo "  make modmul-test"
	@echo "  make transpose-test"
	@echo "  make clean"
