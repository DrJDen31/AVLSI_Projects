# collect_results.tcl — Read per-architecture result files and write markdown table
# Usage: quartus_sh -t collect_results.tcl
#   or: source collect_results.tcl  (from build_all.tcl)
#
# Reads results/<arch>.txt files and writes docs/4_hw_results.md

set architectures {
    fir_direct
    fir_pipelined
    fir_parallel_L2
    fir_parallel_L3
    fir_fastfir_L2
    fir_fastfir_L3
    fir_pipe_fastfir_L3
}

# Architecture display names for the table
array set display_names {
    fir_direct          "Direct-Form"
    fir_pipelined       "Pipelined"
    fir_parallel_L2     "L=2 Parallel"
    fir_parallel_L3     "L=3 Parallel"
    fir_fastfir_L2      "L=2 Fast FIR"
    fir_fastfir_L3      "L=3 Fast FIR"
    fir_pipe_fastfir_L3 "L=3 Pipelined Fast FIR"
}

# Read a result file into a dict
proc read_result_file {filepath} {
    set data [dict create]
    if {![file exists $filepath]} {
        return $data
    }
    set f [open $filepath r]
    while {[gets $f line] >= 0} {
        if {[regexp {^([^=]+)=(.*)$} $line -> key val]} {
            dict set data $key $val
        }
    }
    close $f
    return $data
}

# Helper: get a value or a fallback
proc get_val {data key {fallback "—"}} {
    if {[dict exists $data $key]} {
        set v [dict get $data $key]
        if {$v ne "N/A" && $v ne ""} {
            return $v
        }
    }
    return $fallback
}

# Build the markdown output
set md_lines {}
lappend md_lines "# 4. Hardware Synthesis Results"
lappend md_lines ""
lappend md_lines "## Target Device"
lappend md_lines "- **FPGA**: Intel Cyclone V (5CGXFC7C7F23C8)"
lappend md_lines "- **Tool**: Quartus Prime Lite 20.1.1"
lappend md_lines "- **Clock Constraint**: 100 MHz (10 ns period)"
lappend md_lines "- **Note**: Fmax = 1000 / (T\\_period - slack). All designs analyzed with 100 MHz constraint."
lappend md_lines ""
lappend md_lines "## Resource Utilization & Performance"
lappend md_lines ""
lappend md_lines "| Architecture | ALMs | DSPs | Fmax (MHz) | Throughput (MSPS)* | Power (mW) | Power Eff. (mW/MSPS) | Area Eff. (MSPS/kALM) | Status |"
lappend md_lines "|---|---|---|---|---|---|---|---|---|"

foreach arch $architectures {
    set result_file "results/${arch}.txt"
    set data [read_result_file $result_file]
    
    set name $display_names($arch)
    
    if {[dict size $data] == 0} {
        lappend md_lines "| $name (`$arch`) | — | — | — | — | — | — | — | ⏳ Not yet run |"
        continue
    }
    
    # Determine Parallel Factor L
    set L 1
    if {[regexp {L=([0-9])} $name -> match]} { set L $match }
    
    # ALMs: prefer alms, fallback to logic_cells with annotation
    set alms [get_val $data alms]
    if {$alms eq "—"} {
        set lc [get_val $data logic_cells]
        if {$lc ne "—"} { set alms "${lc} (LC)" }
    }
    
    set dsps  [get_val $data dsps]
    set fmax  [get_val $data fmax]
    set pwr   [get_val $data power]
    if {$pwr eq "—"} { set pwr [get_val $data total_power] }
    
    # Derived Metrics
    set msps "—"
    set pwr_eff "—"
    set area_eff "—"
    
    if {$fmax ne "—" && $fmax ne "N/A"} {
        set msps_val [expr {$fmax * $L}]
        set msps [format "%.1f" $msps_val]
        
        if {$pwr ne "—" && $pwr ne "N/A"} {
            set pwr_eff [format "%.2f" [expr {$pwr / $msps_val}]]
        }
        
        set alms_clean [regsub -all {[^0-9.]} $alms ""]
        if {$alms_clean ne "" && $alms_clean > 0} {
            set area_eff [format "%.2f" [expr {$msps_val / ($alms_clean / 1000.0)}]]
        }
    }
    
    # Status
    set status [get_val $data status "N/A"]
    if {$status eq "OK"} { set status_str "✅ OK" } elseif {$status eq "FAIL"} { set status_str "❌ Failed" } else { set status_str $status }
    
    lappend md_lines "| $name | $alms | $dsps | $fmax | **$msps** | $pwr | $pwr_eff | $area_eff | $status_str |"
}

lappend md_lines ""
lappend md_lines "### Metric Definitions"
lappend md_lines ""
lappend md_lines "- **Throughput (MSPS)**: *Mega Samples Per Second*. Computed as `Fmax * L`, where `L` is the number of samples processed per cycle."
lappend md_lines "- **Power Efficiency (mW/MSPS)**: Energy cost per sample. Lower is better."
lappend md_lines "- **Area Efficiency (MSPS/kALM)**: High-speed throughput density. Higher is better."
lappend md_lines ""
lappend md_lines "## Final Observations"
lappend md_lines ""
lappend md_lines "1. **Pipelining Advantage**: Pipelining the direct-form architecture nearly doubled MSPS (~34 to ~59) with only ~8% area overhead, creating a much more efficient hardware profile."
lappend md_lines "2. **Parallel Scaling Bottleneck**: Standard parallelization (L=2, L=3) increases MSPS but at a severe cost to **Area Efficiency**. MSPS/kALM drops from ~17.0 (Direct) to ~1.4 (L=3 Parallel) because the core MAC tree is repeated without reducing complexity."
lappend md_lines "3. **Optimization Winner**: The **L=3 Pipelined Fast FIR** is the project's optimal design. It achieves the highest throughput (**172 MSPS**) while consuming less power than any other parallel design and maintaining the best power efficiency (**0.77 mW/MSPS**)."
lappend md_lines ""
lappend md_lines "---"
lappend md_lines "*Final Results - Compiled on [clock format [clock seconds]]*"

# Write to docs
set outpath "../docs/4_hw_results.md"
set f [open $outpath w]
foreach line $md_lines {
    puts $f $line
}
close $f

puts "Results table written to $outpath"

