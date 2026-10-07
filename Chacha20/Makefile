.PHONY: sim syn tim clean check-lib

# bash + pipefail so a failing yosys/sta is not hidden by `| tee`
SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c

BUILD_DIR = build
SIM_DIR   = $(BUILD_DIR)/sim_results
SYN_DIR   = $(BUILD_DIR)/reports

# Path to the Liberty file (required for `syn` and `tim`), e.g.:
#   make syn LIB=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib
#   or: export LIB=/path/to/...
LIB ?=

sim:
	@rm -rf $(SIM_DIR)
	@mkdir -p $(SIM_DIR)

	@iverilog -o $(SIM_DIR)/chacha20_sim chacha20.v sim/chacha20_tb.v
	@vvp $(SIM_DIR)/chacha20_sim

	@iverilog -o $(SIM_DIR)/chacha12_sim chacha20.v sim/chacha12_tb.v
	@vvp $(SIM_DIR)/chacha12_sim

	@iverilog -o $(SIM_DIR)/chacha8_sim chacha20.v sim/chacha8_tb.v
	@vvp $(SIM_DIR)/chacha8_sim

check-lib:
	@if [ -z "$(LIB)" ]; then \
		echo "ERROR: LIB is not set. Usage: make $(MAKECMDGOALS) LIB=/abs/path/to/<lib>.lib"; exit 1; \
	elif [ ! -f "$(LIB)" ]; then \
		echo "ERROR: Liberty file not found: $(LIB)"; exit 1; \
	fi

# Yosys synthesis: the <PATH_TO_YOUR_LIBERTY_FILE> placeholder in synth.ys is
# substituted with $(LIB) into a generated script, so synth.ys stays untouched.
syn: check-lib
	@rm -rf $(SYN_DIR)
	@mkdir -p $(SYN_DIR)
	@sed "s|<PATH_TO_YOUR_LIBERTY_FILE>|$(LIB)|g" synth.ys > $(SYN_DIR)/synth_run.ys
	@yosys -s $(SYN_DIR)/synth_run.ys 2>&1 | tee $(SYN_DIR)/yosys.log

# Pre-routing STA on the netlist produced by `syn`.
tim: check-lib
	@test -f $(SYN_DIR)/netlist.v || { echo "ERROR: run 'make syn' first"; exit 1; }
	@LIB="$(LIB)" sta -exit run_sta.tcl 2>&1 | tee $(SYN_DIR)/sta.log

clean:
	@rm -rf $(BUILD_DIR)
