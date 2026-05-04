import os
import pandas as pd
import matplotlib.pyplot as plt

def main():
    os.makedirs('outputs/figures', exist_ok=True)
    
    synth_file = '../synth/synth_summary.csv'
    if not os.path.exists(synth_file):
        print(f"Error: {synth_file} not found.")
        return
        
    df = pd.read_csv(synth_file)
    
    # 1. Throughput Bar Chart
    plt.figure(figsize=(8, 6))
    bars = plt.bar(df['design'], df['throughput_blocks_per_sec'] / 1e6, color=['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728'])
    plt.title('Throughput Comparison (D1-D4)', fontsize=14)
    plt.ylabel('Throughput (Million Blocks / sec)', fontsize=12)
    plt.xlabel('Design Point', fontsize=12)
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    
    # Add value labels
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2, yval + 0.05, f'{yval:.2f}', ha='center', va='bottom', fontsize=10)
        
    plt.tight_layout()
    plt.savefig('outputs/figures/perf_comparison.pdf')
    plt.savefig('outputs/figures/perf_comparison.png', dpi=300)
    plt.close()
    print("Saved perf_comparison.pdf/png")
    
    # 2. Area vs Throughput Scatter Plot
    plt.figure(figsize=(8, 6))
    plt.scatter(df['throughput_blocks_per_sec'] / 1e6, df['alms'], color='darkblue', s=100, zorder=5)
    
    for i, row in df.iterrows():
        plt.annotate(row['design'], 
                     (row['throughput_blocks_per_sec'] / 1e6, row['alms']),
                     xytext=(10, -5), textcoords='offset points', fontsize=12, fontweight='bold')
                     
    plt.title('Area vs Throughput Trade-off', fontsize=14)
    plt.xlabel('Throughput (Million Blocks / sec)', fontsize=12)
    plt.ylabel('Area (ALMs)', fontsize=12)
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig('outputs/figures/area_throughput.pdf')
    plt.savefig('outputs/figures/area_throughput.png', dpi=300)
    plt.close()
    print("Saved area_throughput.pdf/png")

if __name__ == '__main__':
    main()
