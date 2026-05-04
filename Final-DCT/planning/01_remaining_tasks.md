# Remaining Tasks

This document consolidates the remaining issues for the 2D DCT Accelerator project.

## 1. Quartus Visual Artifacts (Manual Capture)

The synthesis data is already populated, but for the final academic report and documentation, we need screenshots from the Intel Quartus GUI.

### Checklist of Images to Capture
Please capture the following screenshots in Quartus Prime and save them exactly as specified:

- [x] **`report/figures/figures/system_block_diagram.pdf`**
  - **What:** Top-level hierarchy system block diagram (draw.io or TikZ).
  - **How:** Create manually and export as PDF to the report figures directory.
- [x] **`report/figures/figures/mac_schematic.pdf`**
  - **What:** MAC unit schematic for the D3 parallel design.
  - **How:** Create manually and export as PDF to the report figures directory.

- [x] **`synth/rtl_viewer_D1.png`**
  - **What:** RTL Viewer Schematic for the D1 (Baseline) architecture.
  - **How:** Open `synth/dct_project.qpf`, set VARIANT=D1, Compile, go to *Tools > Netlist Viewers > RTL Viewer*. Capture the expanded `dct_1d_engine`.
- [x] **`synth/rtl_viewer_D2.png`**
  - **What:** RTL Viewer Schematic for the D2 (Pipelined) architecture.
  - **How:** Set VARIANT=D2, Compile, capture RTL Viewer.
- [x] **`synth/rtl_viewer_D3.png`**
  - **What:** RTL Viewer Schematic for the D3 (Parallel) architecture.
  - **How:** Set VARIANT=D3, Compile, capture RTL Viewer.
- [x] **`synth/rtl_viewer_D4.png`**
  - **What:** RTL Viewer Schematic for the D4 (Pipelined + Parallel) architecture.
  - **How:** Set VARIANT=D4, Compile, capture RTL Viewer.
- [x] **`synth/tech_map_dsp.png`**
  - **What:** Technology Map Viewer showing the successful inference of a DSP block.
  - **How:** Go to *Tools > Netlist Viewers > Technology Map Viewer*, find the multiplier inside the MAC unit, and capture the DSP block instantiation.
- [x] **`synth/tech_map_dsp_parallel.png`**
  - **What:** Technology Map Viewer for D3 or D4 showing 8 DSP blocks operating in parallel.
- [x] **`report/figures/figures/pipeline_waveform.png`**
  - **What:** ModelSim waveform of the top-level pipeline (D2 or D4).
  - **How:** Run `wave_dct_top.tcl`, capture the `valid`/`ready` handshaking and data flowing from the row engine to the column engine.
- [x] **`report/figures/figures/transpose_waveform.png`**
  - **What:** ModelSim waveform of `transpose_buffer.sv`.
  - **How:** Run `wave_transpose.tcl`, capture the write address incrementing row-by-row and the read address incrementing column-by-column.

## 2. GitHub Actions & CI/CD

- [ ] Write `.github/workflows/lint_rtl.yml`: install Verilator, run `--lint-only` on all `.sv` files in `rtl/` and `tb/`.
- [ ] Write `.github/workflows/test_python.yml`: install dependencies, run tests/scripts.
- [ ] Write `.github/workflows/build_report.yml`: compile `report/main.tex` with a LaTeX action; attach the output PDF as a release artifact.
- [ ] Push to GitHub and verify all three CI workflows pass.

## 3. GitHub Pages Deployment

- [ ] Ensure the MkDocs site (`docs/`) is deployed via GitHub Pages.
- [ ] Confirm site is live at `https://<user>.github.io/dct-vlsi-accelerator`.

## 4. Final Verification

- [ ] Ensure `make pdf` runs cleanly for the LaTeX report.
- [ ] Verify that all figures render at the correct size without display errors.
