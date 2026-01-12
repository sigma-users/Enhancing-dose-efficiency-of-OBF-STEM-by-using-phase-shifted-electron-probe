# Enhancing dose efficiency of OBF STEM by using phase shifted electron probe

# Environment
CUDA is required to build and run the code. A Dockerfile is provided to create a reproducible environment with the necessary dependencies.
The code has been tested with CUDA 11.8, A100 80GB GPU.

```bash
# Build Docker image
docker build --no-cache -t obfweight:latest .
```

# Usage
```bash
# Run Docker container with GPU access and mount current directory
docker run --gpus all --rm -it -v "$(pwd)":/workspace/pipeline obfweight:latest

# Inside the container, navigate to the pipeline directory
cd /workspace/pipeline
# Simulate a 4D-STEM dataset with specified parameters
python3.11 pipeline/1_code/0_simulate_4ddataset.py <simulation_config_label>
# Reconstruct the OBF image using the simulated dataset
python3.11 pipeline/1_code/1_reconstruct_obf_image.py <reconstruction_config_label>
```

# Project Structure
```
obfweight/
├── Dockerfile                           # Reproducible environment (CUDA + Python build)
├── Makefile                             # Build libobfweight.a from CUDA source
├── requirements.txt                     # Python dependencies (numpy, etc.)
├── readme.md                            # Usage and reproduction instructions
│
├── include/
│   └── obfweight.hpp                    # Header file for CUDA kernel declarations
│
├── src/
│   └── obfWeight.cu                     # Core CUDA implementation for OBF weight computation
│
├── python/
│   ├── setup.py                         # Build script to expose CUDA code as a Python module
│   └── obfweight/
│       ├── __init__.py                  # Makes the module importable as `import obfweight`
│       └── _obf_cuda.cpp                # C++/CUDA bridge: calls kernel and converts data to NumPy
│
└── pipeline/                            # End-to-end workflow for reproduction
    ├── 0_input/                         # Input parameters, simulation settings, atomic structures
    │   ├── 0_simulate_4d_dataset/
    │   ├── 1_reconstruct_obf_image/
    │   ├── schemas/                     # JSON schema files for input validation
    │   └── structures/
    │
    ├── 1_code/                          # Python scripts for simulation and reconstruction
    │   ├── 0_simulate_4d_dataset.py     # Generates synthetic 4D-STEM datasets
    │   └── 1_reconstruct_obf_image.py   # Reconstructs OBF image using CUDA weights
    │
    └── 2_output/                        # Output results corresponding to the reconstruction pipeline
        ├── 0_simulate_4d_dataset/
        └── 1_reconstruct_obf_image/
            ├── images/
            └── npy/
```
