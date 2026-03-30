# build_one.tcl — Compile a single FIR architecture
# Usage: quartus_sh -t build_one.tcl <architecture_name>
#   e.g. quartus_sh -t build_one.tcl fir_direct

package require ::quartus::project
package require ::quartus::flow

# --- Parse argument ---
if {$argc < 1} {
    puts "Usage: quartus_sh -t build_one.tcl <architecture_name>"
    puts "  e.g. quartus_sh -t build_one.tcl fir_direct"
    exit 1
}
set arch [lindex $argv 0]

set project_name "fir_filters"
set family "Cyclone V"
set device "5CGXFC7C7F23C8"

puts "======================================================="
puts " Compiling Architecture: $arch"
puts "======================================================="

# Ensure results directory exists
file mkdir results

# 1. Create/Open Project — clear previous assignments
if {[project_exists $project_name]} {
    project_open $project_name
    remove_all_global_assignments -name *
    remove_all_instance_assignments -name *
} else {
    project_new $project_name
}

# 2. Set Project Properties
set_global_assignment -name FAMILY $family
set_global_assignment -name DEVICE $device
set_global_assignment -name TOP_LEVEL_ENTITY $arch

# 3. Add Source Files
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/coeff_pkg.sv
set_global_assignment -name SYSTEMVERILOG_FILE ../rtl/${arch}.sv

# 4. DSP chain fix for fastfir architectures
# Cyclone V max DSP chain length is 22. The fastfir designs create chains
# of 46-88, exceeding the device limit. Disabling auto DSP recognition
# forces Quartus to use fabric logic for multipliers instead.
if {[string match "*fastfir*" $arch] && ![string match "*pipe_fastfir*" $arch]} {
    puts "  >> Disabling AUTO_DSP_RECOGNITION for $arch (DSP chain workaround)"
    set_global_assignment -name AUTO_DSP_RECOGNITION OFF
}

# 5. Generate SDC timing constraint (100 MHz target)
set sdc_file [open "timing.sdc" w]
puts $sdc_file "create_clock -name clk -period 10.0 \[get_ports clk\]"
puts $sdc_file "derive_clock_uncertainty"
close $sdc_file
set_global_assignment -name SDC_FILE timing.sdc

export_assignments

# 6. Compile Flow with error catching
set compile_ok 1

puts "Running Analysis & Synthesis..."
if {[catch {execute_module -tool map} res]} {
    puts "Error: Synthesis failed for $arch: $res"
    set compile_ok 0
} else {
    puts "Running Fitter..."
    if {[catch {execute_module -tool fit} res]} {
        puts "Error: Fitting failed for $arch: $res"
        set compile_ok 0
    } else {
        puts "Running Timing Analysis..."
        catch {execute_module -tool sta}
        puts "Running Power Analysis..."
        catch {execute_module -tool pow}
    }
}

# 7. Extract Results
set alms "N/A"
set regs "N/A"
set dsps "N/A"
set fmax "N/A"
set power "N/A"
set slack "N/A"

# Helper to find report file (check output_files/ and root)
proc find_report {name} {
    set paths [list "output_files/$name" "$name"]
    foreach p $paths {
        if {[file exists $p]} { return $p }
    }
    return ""
}

# Extract from fit summary
set fit_rpt [find_report "${project_name}.fit.summary"]
if {$fit_rpt ne ""} {
    set f [open $fit_rpt r]
    while {[gets $f line] >= 0} {
        if {[regexp {Logic utilization \(in ALMs\)\s*:\s*([0-9,]+)} $line -> match]} {
            set alms [string map {"," ""} $match]
        }
        if {[regexp {Total registers\s*:\s*([0-9,]+)} $line -> match]} {
            set regs [string map {"," ""} $match]
        }
        if {[regexp {Total DSP Blocks\s*:\s*([0-9,]+)} $line -> match]} {
            set dsps [string map {"," ""} $match]
        }
    }
    close $f
}

# Extract Fmax from STA summary (Fmax = 1000 / (period - slack))
set sta_rpt [find_report "${project_name}.sta.summary"]
if {$sta_rpt ne ""} {
    set f [open $sta_rpt r]
    set worst_slack 999.0
    while {[gets $f line] >= 0} {
        # Look for Slow model Setup slack (worst case)
        if {[regexp {Slow.*Setup} $line]} {
            # Next non-empty line with "Slack" has the value
            while {[gets $f line2] >= 0} {
                if {[regexp {Slack\s*:\s*(-?[0-9.]+)} $line2 -> s]} {
                    if {$s < $worst_slack} {
                        set worst_slack $s
                        set slack $s
                    }
                    break
                }
            }
        }
    }
    close $f
    
    if {$worst_slack < 999.0} {
        set period 10.0
        set calc_fmax [expr {1000.0 / ($period - $worst_slack)}]
        set fmax [format "%.1f" $calc_fmax]
    }
}

# Extract dynamic power from power summary
set pow_rpt [find_report "${project_name}.pow.summary"]
if {$pow_rpt ne ""} {
    set f [open $pow_rpt r]
    while {[gets $f line] >= 0} {
        if {[regexp {Core Dynamic Thermal Power Dissipation\s*:\s*([0-9.]+)\s*mW} $line -> match]} {
            set power $match
        }
    }
    close $f
}

# 8. Save results to per-architecture file
set result_file [open "results/${arch}.txt" w]
puts $result_file "arch=$arch"
puts $result_file "alms=$alms"
puts $result_file "regs=$regs"
puts $result_file "dsps=$dsps"
puts $result_file "fmax=$fmax"
puts $result_file "slack=$slack"
puts $result_file "power=$power"
puts $result_file "status=[expr {$compile_ok ? "OK" : "FAIL"}]"
puts $result_file "timestamp=[clock format [clock seconds]]"
close $result_file

puts "======================================================="
puts " Results for $arch saved to results/${arch}.txt"
puts "   ALMs=$alms  Regs=$regs  DSPs=$dsps  Fmax=$fmax MHz  Power=$power mW"
puts "======================================================="

# 9. Copy report files to per-architecture backups
file mkdir results/${arch}
foreach ext {fit.summary sta.summary pow.summary} {
    set src [find_report "${project_name}.${ext}"]
    if {$src ne ""} {
        file copy -force $src "results/${arch}/${ext}"
    }
}

project_close
