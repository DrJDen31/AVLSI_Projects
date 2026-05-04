import sys

def read_hex_file(filepath):
    vals = []
    try:
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    val = int(line, 16)
                    # convert to signed 16-bit
                    if val >= 0x8000:
                        val -= 0x10000
                    vals.append(val)
    except FileNotFoundError:
        pass
    return vals

golden = read_hex_file('golden_coeffs_fixed.txt')

report = open('pass_fail_report.txt', 'w')
report.write("Simulation vs Golden Verification Report\n")
report.write("======================================\n\n")

if not golden:
    report.write("ERROR: golden_coeffs_fixed.txt not found or empty.\n")
    report.close()
    sys.exit(1)

all_pass = True

for point in ['D1', 'D2', 'D3', 'D4']:
    sim = read_hex_file(f'sim_coeffs_{point}.txt')
    if not sim:
        report.write(f"[{point}] FAIL: Output file missing or empty.\n")
        all_pass = False
        continue
    
    if len(sim) != len(golden):
        report.write(f"[{point}] FAIL: Length mismatch (sim: {len(sim)}, golden: {len(golden)})\n")
        all_pass = False
        continue
    
    mismatches = 0
    for i, (s, g) in enumerate(zip(sim, golden)):
        if abs(s - g) > 2: # tolerance of 2 LSB
            mismatches += 1
            if mismatches <= 5:
                print(f"[{point}] Mismatch at index {i}: sim={s}, golden={g}")
    
    if mismatches > 0:
        report.write(f"[{point}] FAIL: {mismatches} mismatches found.\n")
        all_pass = False
    else:
        report.write(f"[{point}] PASS: All {len(golden)} coefficients match (tolerance ±2).\n")

report.write(f"\nOVERALL STATUS: {'PASS' if all_pass else 'FAIL'}\n")
report.close()
print(f"OVERALL STATUS: {'PASS' if all_pass else 'FAIL'}")
