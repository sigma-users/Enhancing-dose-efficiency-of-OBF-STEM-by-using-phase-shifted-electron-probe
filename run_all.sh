#!/bin/bash
# This script runs all simulation and reconstruction steps in sequence.

# Step 1: Simulate 4D STEM datasets
python3.11 pipeline/1_code/0_simulate_4d_dataset.py cs_180um_thickness_10nm
python3.11 pipeline/1_code/0_simulate_4d_dataset.py defocus_30nm_thickness_10nm
python3.11 pipeline/1_code/0_simulate_4d_dataset.py no_aberration_thickness_10nm

# Step 2: Reconstruct OBF images from the simulated datasets
python3.11 pipeline/1_code/1_reconstruct_obf_image.py pipeline/0_input/1_reconstruct_obf_image/cs_180um_thickness_10nm_dose_50.json
python3.11 pipeline/1_code/1_reconstruct_obf_image.py pipeline/0_input/1_reconstruct_obf_image/cs_180um_thickness_10nm_dose_inf.json
python3.11 pipeline/1_code/1_reconstruct_obf_image.py pipeline/0_input/1_reconstruct_obf_image/defocus_30nm_thickness_10nm_dose_50.json
python3.11 pipeline/1_code/1_reconstruct_obf_image.py pipeline/0_input/1_reconstruct_obf_image/defocus_30nm_thickness_10nm_dose_inf.json
python3.11 pipeline/1_code/1_reconstruct_obf_image.py pipeline/0_input/1_reconstruct_obf_image/no_aberration_10nm_thickness_dose_50.json
python3.11 pipeline/1_code/1_reconstruct_obf_image.py pipeline/0_input/1_reconstruct_obf_image/no_aberration_10nm_thickness_dose_inf.json
# End of script
