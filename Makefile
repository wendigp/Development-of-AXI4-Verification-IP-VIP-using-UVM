#==============================================================================#
# AXI VIP – UVM + SVA Makefile (QuestaSim 2021.1)
#==============================================================================#

SIM        := questasim
WORK_LIB   := work
TOP        := top

#--------------------------------------------------------------------------
# Tests
#--------------------------------------------------------------------------
TESTS := \
	incr_burst_test \
	raw_hazard_test \
	burst_variation_test

TEST       ?= incr_burst_test
SEED       ?= random
VERBOSITY  ?= UVM_LOW

#--------------------------------------------------------------------------
# Coverage
#--------------------------------------------------------------------------
COV_DIR    := cov
UCDB_MERGE := $(COV_DIR)/axi_vip_merged.ucdb

#--------------------------------------------------------------------------
# Source Files
#--------------------------------------------------------------------------
SV_FILES = \
	axi_defs.sv \
	interface/axi_if.sv \
	assertions/axi_assertions.sv \
	assertions/axi_assertions_bind.sv \
	axi_pkg.sv \
	env/axi_top.sv

#--------------------------------------------------------------------------
# Questa Compile Options
#--------------------------------------------------------------------------
VLOG_OPTS = -sv -timescale 1ns/1ps -L uvm -l comp.log

#--------------------------------------------------------------------------
# Questa Simulation Options (2021.1 FIXED)
#--------------------------------------------------------------------------
VSIM_OPTS = \
	-c \
	-uvmcontrol=all \
	+UVM_TESTNAME=$(TEST) \
	+UVM_VERBOSITY=$(VERBOSITY) \
	-sv_seed $(SEED) \
	-voptargs=+acc \
	-do "coverage save -onexit $(COV_DIR)/$(TEST)_$(SEED).ucdb; run -all; quit" \
	-l sim.log

#--------------------------------------------------------------------------
# Targets
#--------------------------------------------------------------------------
.PHONY: help comp run regress cov all clean

help:
	@echo "------------------------------------------------------------"
	@echo " AXI VIP – UVM + SVA (QuestaSim 2021.1)"
	@echo "------------------------------------------------------------"
	@echo " make comp"
	@echo " make run TEST=<test_name>"
	@echo " make regress"
	@echo " make cov"
	@echo " make all"
	@echo ""
	@echo " Available tests:"
	@for t in $(TESTS); do echo "   - $$t"; done
	@echo "------------------------------------------------------------"

#--------------------------------------------------------------------------
# Compile
#--------------------------------------------------------------------------
comp:
	@echo ">> Compiling AXI VIP..."
	vlib $(WORK_LIB)
	vlog $(VLOG_OPTS) -work $(WORK_LIB) $(SV_FILES)

#--------------------------------------------------------------------------
# Run Single Test (Batch Mode)
#--------------------------------------------------------------------------
run: comp
	@mkdir -p $(COV_DIR)
	@echo ">> Running TEST=$(TEST), SEED=$(SEED)"
	vsim $(WORK_LIB).$(TOP) $(VSIM_OPTS)

#--------------------------------------------------------------------------
# Regression (All tests, multiple seeds)
#--------------------------------------------------------------------------
regress: comp
	@mkdir -p $(COV_DIR)
	@echo ">> Running regression..."
	@for t in $(TESTS); do \
		for s in 1 11 21; do \
			echo ">> TEST=$$t SEED=$$s"; \
			vsim $(WORK_LIB).$(TOP) \
				-c \
				-uvmcontrol=all \
				+UVM_TESTNAME=$$t \
				+UVM_VERBOSITY=$(VERBOSITY) \
				-sv_seed $$s \
				-voptargs=+acc \
				-do "coverage save -onexit $(COV_DIR)/$$t_$$s.ucdb; run -all; quit" \
				-l sim_$$t_$$s.log ; \
		done \
	done

#--------------------------------------------------------------------------
# Coverage Merge & Report
#--------------------------------------------------------------------------
cov:
	@echo ">> Merging coverage..."
	vcover merge $(UCDB_MERGE) $(COV_DIR)/*.ucdb
	@echo ">> Generating HTML coverage report..."
	vcover report -html -details $(UCDB_MERGE)
	@echo ">> Coverage report generated"

#--------------------------------------------------------------------------
# Full Flow
#--------------------------------------------------------------------------
all: clean regress cov

#--------------------------------------------------------------------------
# Clean
#--------------------------------------------------------------------------
clean:
	@echo ">> Cleaning workspace..."
	rm -rf $(WORK_LIB) transcript *.log vsim.wlf
	rm -rf $(COV_DIR) *.ucdb *.wlf *.vstf
