# Advanced VLSI: FIR Filter Evaluation Script
# Automates the compilation and reporting of all 7 FIR architectures.

set project_name "fir_filters"
set family "Cyclone V"
set device "5CGXFC7C7F23C8" 
# Change to your specific FPGA if needed

set architectures {
    "fir_direct"
    "fir_pipelined"
    "fir_parallel_L2"
    "fir_parallel_L3"
    "fir_fastfir_L2"
    "fir_fastfir_L3"
    "fir_pipe_fastfir_L3"
}

# Create a master report file
set report_file [open "../docs/4_hw_results.md" a+]
puts $report_file "\n## Automated Synthesis Results"
puts $report_file "| Architecture | ALMs | Registers | DSP Blocks | Fmax (MHz) | Dynamic Power (mW) |"
puts $report_file "|---|---|---|---|---|---|"

foreach arch $architectures {
    puts "======================================================="
    puts " Compiling Architecture: $arch"
    puts "======================================================="
    
    # 1. Create/Open Project
    if {[project_exists $project_name]} {
        project_open $project_name
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
    
    # Generate an SDC file for timing analysis (100 MHz target)
    set sdc_file [open "timing.sdc" w]
    puts $sdc_file "create_clock -name clk -period 10.0 \[get_ports clk\]"
    puts $sdc_file "derive_clock_uncertainty"
    close $sdc_file
    set_global_assignment -name SDC_FILE timing.sdc
    
    export_assignments

    # 4. Compile Flow
    # Analysis & Synthesis
    catch {execute_module -tool map}
    # Fitter
    catch {execute_module -tool fit}
    # Timing Analysis
    catch {execute_module -tool sta}
    # Power Analysis
    catch {execute_module -tool pow}

    # 5. Extract Results Summary
    set alms "N/A"
    set regs "N/A"
    set dsps "N/A"
    set fmax "N/A"
    set power "N/A"
    
    # Simple grep equivalent for Tcl (extracting from report files)
    set fit_rpt "output_files/${project_name}.fit.summary"
    if {[file exists $fit_rpt]} {
        set f [open $fit_rpt r]
        while {[gets $f line] >= 0} {
            if {[regexp {Logic utilization \(in ALMs\) : \s*([\d\,]+)} $line -> match]} { set alms $match }
            if {[regexp {Total registers : \s*([\d\,]+)} $line -> match]} { set regs $match }
            if {[regexp {Total DSP Blocks : \s*([\d\,]+)} $line -> match]} { set dsps $match }
        }
        close $f
    }
    
    set sta_rpt "output_files/${project_name}.sta.summary"
    if {[file exists $sta_rpt]} {
        set f [open $sta_rpt r]
        while {[gets $f line] >= 0} {
            # Looking for Fmax on 'clk'
            if {[regexp {Fmax.*clk.*:\s*([\d\.]+)\s*MHz} $line -> match]} { set fmax $match }
        }
        close $f
    }
    
    set pow_rpt "output_files/${project_name}.pow.summary"
    if {[file exists $pow_rpt]} {
        set f [open $pow_rpt r]
        while {[gets $f line] >= 0} {
            if {[regexp {Core Dynamic Thermal Power Dissipation : \s*([\d\.]+)\s*mW} $line -> match]} { set power $match }
        }
        close $f
    }
    
    # 6. Append to Markdown Table
    puts $report_file "| \`$arch\` | $alms | $regs | $dsps | $fmax | $power |"
    
    project_close
}

close $report_file
puts "Done! Automated results appended to docs/4_hw_results.md"
