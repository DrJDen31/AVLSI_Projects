import os
import numpy as np
from scipy.fft import idct
from PIL import Image

# JPEG luminance Q-table at QF=70 (same as MATLAB script)
Q_base = np.array([
    [16, 11, 10, 16, 24, 40, 51, 61],
    [12, 12, 14, 19, 26, 58, 60, 55],
    [14, 13, 16, 24, 40, 57, 69, 56],
    [14, 17, 22, 29, 51, 87, 80, 62],
    [18, 22, 37, 56, 68, 109, 103, 77],
    [24, 35, 55, 64, 81, 104, 113, 92],
    [49, 64, 78, 87, 103, 121, 120, 101],
    [72, 92, 95, 98, 112, 100, 103, 99]
])
qf = 70
scale = 200 - 2 * qf
Q_TABLE = np.maximum(np.minimum(np.floor((Q_base * scale + 50) / 100), 255), 1)

def load_hex_output(filepath):
    """Parse sim_coeffs_Dx.txt into a numpy array of 8x8 coefficient blocks."""
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

def idct_2d_all_blocks(blocks):
    """Dequantize using JPEG Q-table then apply scipy.fft.idct row-then-column to each block."""
    out_blocks = np.zeros_like(blocks, dtype=float)
    for i in range(blocks.shape[0]):
        # Scipy's idct needs norm='ortho' to match the DCT scaling used in MATLAB/RTL
        # IDCT on columns (axis=0), then rows (axis=1)
        recon_blk = idct(idct(blocks[i], axis=0, norm='ortho'), axis=1, norm='ortho')
        out_blocks[i] = recon_blk
        
    return out_blocks

def reconstruct_from_blocks(blocks, image_cols=512):
    """Stitch 8x8 blocks back into a full image, clip to [0, 255]."""
    num_blocks = blocks.shape[0]
    
    # We figure out the rows/cols based on num_blocks and original image width
    blocks_per_row = image_cols // 8
    
    # If we have less blocks than a full row, adjust
    if num_blocks < blocks_per_row:
        blocks_per_row = num_blocks
        
    num_rows = ((num_blocks + blocks_per_row - 1) // blocks_per_row) * 8
    num_cols = blocks_per_row * 8
    
    image = np.zeros((num_rows, num_cols), dtype=float)
    
    for i in range(num_blocks):
        br = (i // blocks_per_row) * 8
        bc = (i % blocks_per_row) * 8
        image[br:br+8, bc:bc+8] = blocks[i]
        
    image = np.clip(image, 0, 255)
    return image

if __name__ == "__main__":
    os.makedirs('outputs', exist_ok=True)
    
    # Check how many blocks we actually simulated by looking at test_vectors.hex or golden_coeffs.txt
    # Or just assume 512 width and it will figure it out
    for pt in ['D1', 'D2', 'D3', 'D4']:
        sim_file = f'../sim/sim_coeffs_{pt}.txt'
        if not os.path.exists(sim_file):
            print(f"Skipping {pt}: {sim_file} not found.")
            continue
            
        coeffs = load_hex_output(sim_file)
        blocks = idct_2d_all_blocks(coeffs)
        # Using image_cols=512 based on baboon.tiff
        image_data = reconstruct_from_blocks(blocks, image_cols=512)
        
        image = Image.fromarray(image_data.astype(np.uint8))
        out_path = f'outputs/reconstructed_{pt}.png'
        image.save(out_path)
        print(f"Saved {out_path} ({image_data.shape[0]}x{image_data.shape[1]})")
