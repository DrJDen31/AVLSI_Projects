import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
from PIL import Image

def load_hex_output(filepath):
    vals = []
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                val = int(line, 16)
                if val >= 0x8000:
                    val -= 0x10000
                vals.append(val)
    vals = np.array(vals)
    num_blocks = len(vals) // 64
    blocks = vals.reshape((num_blocks, 8, 8))
    return blocks

def plot_energy_heatmap():
    coeffs_file = '../sim/sim_coeffs_D4.txt'
    if not os.path.exists(coeffs_file):
        print(f"Skipping energy heatmap: {coeffs_file} not found.")
        return
        
    blocks = load_hex_output(coeffs_file)
    mean_energy = np.mean(np.abs(blocks), axis=0)
    
    plt.figure(figsize=(6, 5))
    im = plt.imshow(mean_energy, cmap='inferno', norm=LogNorm())
    plt.colorbar(im, label='Mean Absolute Coefficient Value (Log Scale)')
    plt.title('2D DCT Energy Concentration (Avg over 4096 blocks)', fontsize=12)
    plt.xlabel('Horizontal Frequency', fontsize=10)
    plt.ylabel('Vertical Frequency', fontsize=10)
    plt.xticks(range(8))
    plt.yticks(range(8))
    plt.tight_layout()
    plt.savefig('outputs/figures/energy_heatmap.pdf')
    plt.savefig('outputs/figures/energy_heatmap.png', dpi=300)
    plt.close()
    print("Saved energy_heatmap.pdf/png")

def plot_error_histogram():
    orig_path = '../matlab/images/baboon.tiff'
    d4_path = 'outputs/reconstructed_D4.png'
    
    if not os.path.exists(orig_path) or not os.path.exists(d4_path):
        print("Skipping error histogram: missing images.")
        return
        
    orig_img = Image.open(orig_path).convert('L')
    d4_img = Image.open(d4_path).convert('L')
    
    orig_arr = np.array(orig_img, dtype=float)
    d4_arr = np.array(d4_img, dtype=float)
    
    # Calculate error (Original - Reconstructed)
    error = orig_arr - d4_arr
    error_flat = error.flatten()
    
    plt.figure(figsize=(8, 5))
    # We expect errors to be very small integer values. Bins centered on integers.
    min_err = np.floor(np.min(error_flat))
    max_err = np.ceil(np.max(error_flat))
    bins = np.arange(min_err - 0.5, max_err + 1.5, 1)
    
    plt.hist(error_flat, bins=bins, color='steelblue', edgecolor='black')
    plt.yscale('log') # Log scale because 0 error will dominate heavily
    plt.title('Error Distribution (Original vs D4)', fontsize=14)
    plt.xlabel('Pixel Value Difference (Orig - D4)', fontsize=12)
    plt.ylabel('Count (Log Scale)', fontsize=12)
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig('outputs/figures/error_histogram.pdf')
    plt.savefig('outputs/figures/error_histogram.png', dpi=300)
    plt.close()
    print("Saved error_histogram.pdf/png")

def plot_hardware_breakdown():
    synth_file = '../synth/synth_summary.csv'
    if not os.path.exists(synth_file):
         print("Skipping hardware breakdown: csv not found.")
         return
         
    df = pd.read_csv(synth_file)
    
    fig, ax1 = plt.subplots(figsize=(8, 6))
    
    x = np.arange(len(df['design']))
    width = 0.35
    
    # Grouped Bar for ALMs and Registers
    rects1 = ax1.bar(x - width/2, df['alms'], width, label='ALMs', color='#1f77b4')
    rects2 = ax1.bar(x + width/2, df['registers'], width, label='Registers', color='#ff7f0e')
    
    ax1.set_ylabel('Resource Count (ALMs / Registers)', fontsize=12)
    ax1.set_title('Hardware Resource Breakdown by Design', fontsize=14)
    ax1.set_xticks(x)
    ax1.set_xticklabels(df['design'])
    ax1.legend(loc='upper left')
    ax1.grid(axis='y', linestyle='--', alpha=0.7)
    
    # Add a secondary y-axis for DSP blocks since scale is so different (1 to 8)
    ax2 = ax1.twinx()
    # Plot DSPs as a line with markers
    ax2.plot(x, df['dsp_blocks'], color='red', marker='D', markersize=8, linewidth=2, label='DSP Blocks (Right Axis)')
    ax2.set_ylabel('DSP Blocks', fontsize=12, color='red')
    ax2.tick_params(axis='y', labelcolor='red')
    # Force integer ticks for DSP
    ax2.set_yticks(range(0, 10, 2))
    
    # Combine legends from both axes
    lines_1, labels_1 = ax1.get_legend_handles_labels()
    lines_2, labels_2 = ax2.get_legend_handles_labels()
    ax1.legend(lines_1 + lines_2, labels_1 + labels_2, loc='upper left')
    
    fig.tight_layout()
    plt.savefig('outputs/figures/hardware_breakdown.pdf')
    plt.savefig('outputs/figures/hardware_breakdown.png', dpi=300)
    plt.close()
    print("Saved hardware_breakdown.pdf/png")

def plot_efficiency():
    synth_file = '../synth/synth_summary.csv'
    if not os.path.exists(synth_file):
         return
         
    df = pd.read_csv(synth_file)
    
    # Efficiency = Throughput / ALMs
    df['efficiency'] = df['throughput_blocks_per_sec'] / df['alms']
    
    plt.figure(figsize=(8, 6))
    bars = plt.bar(df['design'], df['efficiency'], color='teal')
    plt.title('Throughput-per-Area Efficiency', fontsize=14)
    plt.xlabel('Design Point', fontsize=12)
    plt.ylabel('Efficiency (Blocks/sec / ALM)', fontsize=12)
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2, yval + 10, f'{yval:.0f}', ha='center', va='bottom', fontsize=11)
        
    plt.tight_layout()
    plt.savefig('outputs/figures/efficiency.pdf')
    plt.savefig('outputs/figures/efficiency.png', dpi=300)
    plt.close()
    print("Saved efficiency.pdf/png")

def main():
    os.makedirs('outputs/figures', exist_ok=True)
    plot_energy_heatmap()
    plot_error_histogram()
    plot_hardware_breakdown()
    plot_efficiency()

if __name__ == '__main__':
    main()
