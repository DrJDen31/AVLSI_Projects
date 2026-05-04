import os
import matplotlib.pyplot as plt
import matplotlib.patches as patches

def main():
    os.makedirs('outputs/figures', exist_ok=True)
    
    fig, ax = plt.subplots(figsize=(10, 5))
    
    # Define timing diagram parameters
    cycles = 10
    stages = ['Clock', 'Pixel Input', 'ROM Read', 'Multiply', 'Accumulate', 'Coeff Output']
    colors = ['#ffffff', '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd']
    
    ax.set_xlim(0, cycles)
    ax.set_ylim(0, len(stages))
    
    # Draw Clock
    for i in range(cycles):
        ax.add_patch(patches.Rectangle((i, len(stages)-1 + 0.25), 0.5, 0.5, facecolor='black'))
        ax.plot([i, i, i+0.5, i+0.5, i+1], [len(stages)-1+0.25, len(stages)-1+0.75, len(stages)-1+0.75, len(stages)-1+0.25, len(stages)-1+0.25], color='black', lw=1.5)
        
    # Draw Pipeline Stages (D2/D4 approximation)
    for row, stage in enumerate(reversed(stages[1:])):
        # Calculate start cycle for this stage (delaying by 1 cycle per stage)
        start_cycle = row + 1
        for i in range(start_cycle, min(start_cycle + 5, cycles)):
            ax.add_patch(patches.Rectangle((i+0.1, row+0.1), 0.8, 0.8, facecolor=colors[row+1], edgecolor='black', alpha=0.7))
            ax.text(i+0.5, row+0.5, f'Data {i-start_cycle}', ha='center', va='center', color='white', fontweight='bold', fontsize=9)

    ax.set_yticks([i + 0.5 for i in range(len(stages))])
    ax.set_yticklabels(reversed(stages), fontsize=12)
    ax.set_xticks(range(cycles + 1))
    ax.set_xticklabels([f'T{i}' for i in range(cycles + 1)])
    ax.grid(axis='x', linestyle='--', alpha=0.5)
    
    plt.title('D2/D4 Pipelined Architecture Timing Diagram', fontsize=14)
    plt.tight_layout()
    plt.savefig('outputs/figures/pipeline_waveform.pdf')
    plt.savefig('outputs/figures/pipeline_waveform.png', dpi=300)
    plt.close()
    print("Saved pipeline_waveform.pdf/png")

if __name__ == '__main__':
    main()
