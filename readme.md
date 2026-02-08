# Enhancing dose efficiency of OBF STEM by using phase shifted electron probe
This repository contains the code and instructions to reproduce the results from the paper: "Enhancing dose efficiency of OBF STEM by using phase shifted electron probe".

## Prerequisites
- CUDA
- Docker
- NVIDIA Container Toolkit

The code has been tested in the following environments:
- Environment 1:
    - On-premise server
    - Ubuntu 22.04.4 LTS
    - NVIDIA A100 80GB GPU (CUDA 12.4)
    - Docker 26.1.2
    - NVIDIA Container Toolkit 1.16.2
- Environment 2:
    - AWS EC2 g5g.xlarge instance
    - NVIDIA T4G GPU (CUDA 12.8)
    - Ubuntu 24.04.3 LTS
    - Docker 29.2.1
    - NVIDIA Container Toolkit 1.18.2

```bash
# Build Docker image (root permission may be required)
docker build --no-cache -t obfweight:latest .
```

## Usage
Should you have trouble running the code, please refer to the Troubleshooting section below.
```bash
# Run Docker container with GPU access and mount current directory
docker run --gpus all --rm -it -v "$(pwd)":/workspace obfweight:latest

# Inside the container, navigate to the pipeline directory
cd /workspace/pipeline
```
After entering the container, you can run the full pipeline or individual steps by commands in the following sections.

### Run the entire pipeline:
```bash
# Execute the full simulation and reconstruction pipeline
bash run_all.sh
```

### Run individually:
```bash
# Simulate a 4D-STEM dataset with specified parameters
python3.11 pipeline/1_code/0_simulate_4d_dataset.py <simulation_config_label>
# Reconstruct the OBF image using the simulated dataset
python3.11 pipeline/1_code/1_reconstruct_obf_image.py <reconstruction_config_label>
```

Result files will be saved in the `pipeline/2_output/` directory.

The `<simulation_config_label>` and `<reconstruction_config_label>` corresponds to the JSON filenames in `pipeline/0_input/0_simulate_4d_dataset/` and `pipeline/0_input/1_reconstruct_obf_image/` respectively (without the .json extension).

### Input Configuration
The details of the input json files is described in the schemas in `pipeline/0_input/schemas`. Examples can been found in `pipeline/0_input/0_simulate_4d_dataset/` and `pipeline/0_input/1_reconstruct_obf_image/`.

The basic json structure for simulation configuration is as follows:
```json
{
    "structure": "<filename>",
    "tile_size": [<int>, <int>, <int>],
    "df": <number>,
    "cs": <number>,
    "energy": <number>,
    "semiangle_cutoff": <number>,
    "potential_sampling": <number>,
    "max_detection_angle": <number>
}
```
| Key                   | Type         | Description                                                                                                      |
| --------------------- | ------------ | ---------------------------------------------------------------------------------------------------------------- |
| `structure`           | string       | Filename of an ASE-readable atomic structure located under `pipeline/0_input/structures/`.                       |
| `tile_size`           | array(int,3) | Number of unit cell tiling along x, y, and z axes. The z dimension controls the effective specimen thickness. |
| `df`                  | number       | Defocus value in Angstrom.                                                                                              |
| `cs`                  | number       | Spherical aberration coefficient in Angstrom.                                                                           |
| `energy`              | number       | Beam energy in keV.                                                                                              |
| `semiangle_cutoff`    | number       | Semiangle cutoff in mrad.                                                                               |
| `potential_sampling`  | number       | Potential sampling along xy axes in Angstrom.                                                            |
| `max_detection_angle` | number       | Maximum detection angle in mrad.                                                                                 |


The json structure for reconstruction configuration is as follows:
```json
{
    "simulation_config_label": "<label>",
    "dose": <number or 'inf'>,
    "fwhm": <number>,
    "tile_size": [<int>, <int>]
}
```
| Key                       | Type              | Description                                                                         |
| ------------------------- | ----------------- | ----------------------------------------------------------------------------------- |
| `simulation_config_label` | string            | filename of the 4D-STEM simulation config (without .json).    |
| `dose`                    | number or `"inf"` | Electron dose per square Angstrom. Use `"inf"` for ideal noise-free reconstruction.              |
| `fwhm`                    | number            | Full width at half maximum of the Gaussian blur applied to simulate probe size (Angstrom). |
| `tile_size`               | array(int,2)      | # Tile the scan axes of the 4D dataset into (nx, ny)                    |


## Troubleshooting
Below are common errors you may encounter, along with their solutions.

### "No space left on device" error
Cause: Insufficient disk space.

Solution: Increase the storage size of your instance.

Note: Default EC2 instances often come with only 8 GB of storage, which may be insufficient. We recommend increasing the storage to at least 50 GB to resolve this issue.

### "Permission denied" error
Cause: Lack of necessary privileges to run Docker commands.
Solution:

Prefix your commands with `sudo` (e.g., `sudo docker build ...`).

Alternatively, add your current user to the docker group to run Docker without root privileges.

### "could not select device driver... with capabilities: [[gpu]]" error
Cause: The NVIDIA GPU is not detected or the necessary software is missing.

Solution:

1. Ensure your machine has a compatible NVIDIA GPU.

2. Ensure `NVIDIA drivers` and the `NVIDIA Container Toolkit` are installed.

Note: Standard Ubuntu EC2 AMIs do not come with GPU drivers pre-installed. They must be installed manually.

## Project Structure
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
    │   ├── schemas/                     # JSON schema files for input json file format
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
