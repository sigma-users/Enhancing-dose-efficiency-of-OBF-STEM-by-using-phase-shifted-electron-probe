#!/bin/bash
# This script runs all simulation and reconstruction steps in sequence.

# Step 1: Simulate 4D STEM datasets
python3.11 pipeline/1_code/0_simulate_4d_dataset.py cs_180um_thickness_10nm
python3.11 pipeline/1_code/0_simulate_4d_dataset.py defocus_30nm_thickness_10nm
python3.11 pipeline/1_code/0_simulate_4d_dataset.py no_aberration_thickness_10nm

# Step 2: Reconstruct OBF images from the simulated datasets
python3.11 pipeline/1_code/1_reconstruct_obf_image.py cs_180um_thickness_10nm_dose_50
python3.11 pipeline/1_code/1_reconstruct_obf_image.py cs_180um_thickness_10nm_dose_inf
python3.11 pipeline/1_code/1_reconstruct_obf_image.py defocus_30nm_thickness_10nm_dose_50
python3.11 pipeline/1_code/1_reconstruct_obf_image.py defocus_30nm_thickness_10nm_dose_inf
python3.11 pipeline/1_code/1_reconstruct_obf_image.py no_aberration_thickness_10_nm_dose_50
python3.11 pipeline/1_code/1_reconstruct_obf_image.py no_aberration_thickness_10_nm_dose_inf
# End of script
