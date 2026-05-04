import os
import numpy as np
import matplotlib.pyplot as plt
from PIL import Image

def main():
    os.makedirs('outputs/figures', exist_ok=True)
    
    orig_path = '../matlab/images/baboon.tiff'
    d1_path = 'outputs/reconstructed_D1.png'
    d4_path = 'outputs/reconstructed_D4.png'
    
    if not os.path.exists(orig_path) or not os.path.exists(d1_path) or not os.path.exists(d4_path):
        print("Missing images for image_diff.py. Need original, D1, and D4.")
        return
        
    orig_img = Image.open(orig_path).convert('L')
    d1_img = Image.open(d1_path).convert('L')
    d4_img = Image.open(d4_path).convert('L')
    
    orig_arr = np.array(orig_img, dtype=float)
    d1_arr = np.array(d1_img, dtype=float)
    d4_arr = np.array(d4_img, dtype=float)
    
    # Match shapes
    h, w = d1_arr.shape
    orig_crop = orig_arr[0:h, 0:w]
    
    # Calculate absolute difference
    diff_arr = np.abs(orig_crop - d4_arr)
    
    # Plot 5 panels
    fig, axes = plt.subplots(1, 5, figsize=(20, 5))
    
    # 0: Original
    im0 = axes[0].imshow(orig_crop, cmap='gray', vmin=0, vmax=255)
    axes[0].set_title('Original', fontsize=12)
    axes[0].axis('off')
    
    # 1: D1
    im1 = axes[1].imshow(d1_arr, cmap='gray', vmin=0, vmax=255)
    axes[1].set_title('D1 Reconstructed', fontsize=12)
    axes[1].axis('off')
    
    # 2: D4
    im2 = axes[2].imshow(d4_arr, cmap='gray', vmin=0, vmax=255)
    axes[2].set_title('D4 Reconstructed', fontsize=12)
    axes[2].axis('off')
    
    # 3: Diff (Full Scale)
    im3 = axes[3].imshow(diff_arr, cmap='hot', vmin=0, vmax=255)
    axes[3].set_title('Diff (Scale 0-255)', fontsize=12)
    axes[3].axis('off')
    plt.colorbar(im3, ax=axes[3], fraction=0.046, pad=0.04)
    
    # 4: Diff (Sensitive Scale)
    im4 = axes[4].imshow(diff_arr, cmap='hot', vmin=0, vmax=5)
    axes[4].set_title('Diff (Scale 0-5)', fontsize=12)
    axes[4].axis('off')
    plt.colorbar(im4, ax=axes[4], fraction=0.046, pad=0.04)
    
    plt.tight_layout()
    plt.savefig('outputs/figures/image_comparison.pdf')
    plt.savefig('outputs/figures/image_comparison.png', dpi=300)
    plt.close()
    print("Saved updated image_comparison.pdf/png with sensitive heatmap.")

if __name__ == '__main__':
    main()
