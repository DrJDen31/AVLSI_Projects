# build_all.tcl — Parent script: compile selected FIR architectures
# Usage: quartus_sh -t build_all.tcl
#
# Configure the SKIP list below to avoid re-running completed architectures.
# Each architecture is compiled via build_one.tcl in a subprocess.
# After all runs, collect_results.tcl is called to generate the results table.

# =====================================================================
#  CONFIGURATION — Edit these lists to control which architectures run
# =====================================================================

# All available architectures (in order)
set all_architectures {
    fir_direct
    fir_pipelined
    fir_parallel_L2
    fir_parallel_L3
    fir_fastfir_L2
    fir_fastfir_L3
    fir_pipe_fastfir_L3
}

# Architectures to SKIP (already have valid results in results/<arch>.txt)
# Comment out or clear this list to run everything.
set skip_architectures {
    fir_direct
    fir_parallel_L2
    fir_parallel_L3
    fir_fastfir_L2
    fir_fastfir_L3
}

# =====================================================================
#  EXECUTION
# =====================================================================

# Determine the Quartus shell executable path
set quartus_bin [file dirname [info nameofexecutable]]
set quartus_sh [file join $quartus_bin quartus_sh.exe]
if {![file exists $quartus_sh]} {
    # Fallback: try just the executable name (assumes it's on PATH)
    set quartus_sh "quartus_sh"
}

set script_dir [file dirname [info script]]
set build_one_script [file join $script_dir build_one.tcl]

puts "======================================================="
puts " FIR Filter Batch Synthesis"
puts " Skipping: $skip_architectures"
puts "======================================================="

set run_count 0
set fail_count 0

foreach arch $all_architectures {
    # Check skip list
    if {[lsearch -exact $skip_architectures $arch] >= 0} {
        if {[file exists "results/${arch}.txt"]} {
            puts "\n>> SKIPPING $arch (already has results)"
            continue
        } else {
            puts "\n>> $arch is in skip list but has no results file — running anyway"
        }
    }
    
    puts "\n>> Running build_one.tcl for $arch ..."
    incr run_count

    # Execute child script as a subprocess so each architecture is isolated
    set rc [catch {exec $quartus_sh -t $build_one_script $arch} output]
    puts $output
    
    if {$rc != 0} {
        puts ">> WARNING: build_one.tcl returned non-zero for $arch"
        incr fail_count
    }
}

puts "\n======================================================="
puts " Batch complete: $run_count architecture(s) compiled, $fail_count failure(s)"
puts "======================================================="

# Collect all results into the markdown table
puts "\n>> Collecting results..."
source [file join $script_dir collect_results.tcl]
