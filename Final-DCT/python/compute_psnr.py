import os
import numpy as np
from PIL import Image
import pandas as pd
from scipy.ndimage import uniform_filter

def compute_psnr(img1, img2):
    mse = np.mean((img1 - img2) ** 2)
    if mse == 0:
        return float('inf')
    return 10 * np.log10(255.0**2 / mse)

def compute_ssim(img1, img2):
    """Compute SSIM using scipy uniform filter, simplified."""
    C1 = (0.01 * 255)**2
    C2 = (0.03 * 255)**2
    
    img1 = img1.astype(float)
    img2 = img2.astype(float)
    
    size = 11
    # To handle small images (like 8x128), we reduce filter size if needed
    if img1.shape[0] < size:
        size = img1.shape[0]
        if size % 2 == 0:
            size -= 1
        if size < 3:
            size = 3
    
    mu1 = uniform_filter(img1, size=size)
    mu2 = uniform_filter(img2, size=size)
    
    mu1_sq = mu1**2
    mu2_sq = mu2**2
    mu1_mu2 = mu1 * mu2
    
    sigma1_sq = uniform_filter(img1**2, size=size) - mu1_sq
    sigma2_sq = uniform_filter(img2**2, size=size) - mu2_sq
    sigma12 = uniform_filter(img1 * img2, size=size) - mu1_mu2
    
    ssim_map = ((2 * mu1_mu2 + C1) * (2 * sigma12 + C2)) / \
               ((mu1_sq + mu2_sq + C1) * (sigma1_sq + sigma2_sq + C2))
               
    return np.mean(ssim_map)

if __name__ == "__main__":
    orig_path = '../matlab/images/baboon.tiff'
    if not os.path.exists(orig_path):
        print(f"Error: {orig_path} not found.")
        exit(1)
        
    orig_img = Image.open(orig_path).convert('L')
    orig_array = np.array(orig_img, dtype=float)
    
    results = []
    
    for pt in ['D1', 'D2', 'D3', 'D4']:
        recon_path = f'outputs/reconstructed_{pt}.png'
        if not os.path.exists(recon_path):
            print(f"Skipping {pt}: {recon_path} not found.")
            continue
            
        recon_img = Image.open(recon_path).convert('L')
        recon_array = np.array(recon_img, dtype=float)
        
        h, w = recon_array.shape
        # Crop original to match the shape of the reconstructed image
        # Assuming the simulation started from the top-left corner
        orig_crop = orig_array[0:h, 0:w]
        
        psnr = compute_psnr(orig_crop, recon_array)
        ssim = compute_ssim(orig_crop, recon_array)
        
        results.append({
            'Design': pt,
            'PSNR (dB)': round(psnr, 2),
            'SSIM': round(ssim, 4)
        })
        
        if psnr < 30.0:
            print(f"WARNING: {pt} PSNR is {psnr:.2f} dB, which is below the 30 dB threshold!")
            
    df = pd.DataFrame(results)
    os.makedirs('outputs', exist_ok=True)
    df.to_csv('outputs/psnr_table.csv', index=False)
    print("Saved outputs/psnr_table.csv")
    print(df.to_string(index=False))
