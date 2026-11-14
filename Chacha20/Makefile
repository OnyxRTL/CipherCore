.PHONY: sim syn tim gds clean check-lib

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

# Pick the constraint file based on the Liberty filename
ifeq ($(findstring sky130,$(LIB)),sky130)
  CONSTR := constr_sky130.txt
else ifeq ($(findstring sg13g2,$(LIB)),sg13g2)
  CONSTR := constr_ihp.txt
else ifeq ($(findstring Nangate,$(LIB)),Nangate)
  CONSTR := constr_nangate.txt
else ifneq ($(strip $(LIB)),)
  $(error Cannot determine PDK from LIB=$(LIB). Expected sky130, sg13g2, or Nangate in the filename.)
endif

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
	@sed -e "s|<PATH_TO_YOUR_LIBERTY_FILE>|$(LIB)|g" \
	     -e "s|<PATH_TO_CONSTR_FILE>|$(CONSTR)|g" \
	     synth.ys > $(SYN_DIR)/synth_run.ys
	@yosys -s $(SYN_DIR)/synth_run.ys 2>&1 | tee $(SYN_DIR)/yosys.log

# Pre-routing STA on the netlist produced by `syn`.
tim: check-lib
	@test -f $(SYN_DIR)/netlist.v || { echo "ERROR: run 'make syn' first"; exit 1; }
	@LIB="$(LIB)" sta -exit run_sta.tcl 2>&1 | tee $(SYN_DIR)/sta.log

# RTL-to-GDSII on SKY130 (sky130_fd_sc_hd) with LibreLane, configured by
# librelane/config.json. LibreLane runs from its release container and fetches
# the sky130 PDK revision that release pins into $(PDK_ROOT), so the tools and
# the PDK are the same on every machine. To use a LibreLane $(LIBRELANE_VERSION)
# already installed on the host (for example from its Nix flake) instead:
#   make gds LIBRELANE=librelane
LIBRELANE_VERSION := 3.1.0.dev4
LIBRELANE_IMAGE   ?= ghcr.io/librelane/librelane:$(LIBRELANE_VERSION)
PDK_ROOT          ?= $(HOME)/.ciel
GDS_DIR            = $(BUILD_DIR)/gds
LIBRELANE         ?= docker run --rm --user $(shell id -u):$(shell id -g) -e HOME=/tmp \
                     -v $(CURDIR):$(CURDIR) -v $(PDK_ROOT):$(PDK_ROOT) -w $(CURDIR) \
                     $(LIBRELANE_IMAGE) librelane

gds:
	@rm -rf $(GDS_DIR)
	@mkdir -p $(GDS_DIR) $(PDK_ROOT)
	$(LIBRELANE) --pdk-root $(PDK_ROOT) --pdk sky130A --force-run-dir $(GDS_DIR) librelane/config.json

clean:
	@rm -rf $(BUILD_DIR)
