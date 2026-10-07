# ---------------------------------------------------------------------------
# Pre-Routing Static Timing Analysis (STA) Script for OpenSTA
#
# Usage (normally via `make tim LIB=...`):
#   LIB=/abs/path/to/<lib>.lib sta -exit run_sta.tcl
# ---------------------------------------------------------------------------

# Configuration (LIB is required and is read from the environment)
if {![info exists ::env(LIB)] || $::env(LIB) eq ""} {
    puts "ERROR: environment variable LIB (path to Liberty file) is not set."
    exit 1
}
set lib_file   $::env(LIB)
set netlist    "build/reports/netlist.v"
set top_module "chacha20"
set target_ns  1.0
set rpt_file   "build/reports/worst_path.rpt"

# 1. Read the Liberty model (same .lib that was used for synthesis)
read_liberty $lib_file

# 2. Read the synthesized gate-level netlist from Yosys
read_verilog $netlist

# 3. Link the design to the top module
link_design $top_module

# 4. Create a virtual aggressive clock (1 ns = 1 GHz).
#    This guarantees a violation so we can derive the true Fmax ceiling.
create_clock -name clk -period $target_ns [get_ports clk]

# 5. Check for unconstrained paths or floating pins.
#    (I/O delays are intentionally not set: Fmax is reported for the
#     register-to-register paths only.)
check_setup

# 6. Detailed report of the worst critical path
set fields {slew capacitance fanout input_pins}
report_checks -path_delay max -fields $fields -format full_clock_expanded

# 7. Worst Negative Slack (WNS) -> minimum period and Fmax
set worst_slack [sta::worst_slack -max]
set min_period  [expr {$target_ns - $worst_slack}]
set fmax        [expr {1000.0 / $min_period}]

puts "--------------------------------------------------------"
puts " Pre-Routing Timing Performance Results"
puts "--------------------------------------------------------"
puts [format "Target Clock Period : %.2f ns" $target_ns]
puts [format "Worst Slack Observed: %.3f ns" $worst_slack]
puts [format "Minimum Clock Period: %.3f ns" $min_period]
puts [format "Estimated Pre-Route Fmax: %.2f MHz" $fmax]
puts "--------------------------------------------------------"

# Save the worst path to a file
report_checks -path_delay max -fields $fields -format full_clock_expanded > $rpt_file

exit
