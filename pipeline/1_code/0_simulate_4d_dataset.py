# -*- coding: utf-8 -*-
"""Simulate 4D STEM dataset using abTEM.

This script simulates a 4D STEM dataset based on a given configuration.
The configuration is provided in a JSON file located in the `pipeline/0_input/0_simulate_4d_dataset` directory.
The result is saved as a pickle file in the `pipeline/2_output/0_simulate_4d_dataset` directory.
"""

import abtem
import json
from ase.io import read
import pathlib
import argparse
import pickle
from logging import getLogger, basicConfig, INFO


basicConfig(level=INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = getLogger(__name__)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Simulate 4D dataset")
    parser.add_argument("config_label", type=str, help="Configuration label")
    parser.add_argument("--device", type=str, default="gpu", choices=["cpu", "gpu"], help="Computation device")
    args = parser.parse_args()

    logger.info(f"Starting 4D dataset simulation with config: {args.config_label} on device: {args.device}")
    input_dir = pathlib.Path(__file__).parent.parent / "0_input"
    config_path = input_dir / "0_simulate_4d_dataset" / f"{args.config_label}.json"
    with open(config_path) as f:
        config = json.load(f)

    logger.info(f"Configuration loaded: {config}")
    device = args.device

    # Load atoms
    structure_path = input_dir / "structures" / config["structure"]
    if not structure_path.exists():
        raise FileNotFoundError(f"Structure file not found: {structure_path}")
    unitcell = read(structure_path)
    atoms = unitcell * config["tile_size"]

    logger.info(f"Structure loaded: {structure_path}, unit cell size: {unitcell.get_cell_lengths_and_angles()}, tiled size: {atoms.get_cell_lengths_and_angles()}")
    # Build potential
    potential = abtem.Potential(atoms, sampling=config["potential_sampling"], device=device)

    logger.info(f"Potential built with sampling: {config['potential_sampling']}")
    # Set up probe
    probe = abtem.Probe(
        energy=config["energy"],
        semiangle_cutoff=config["semiangle_cutoff"],
        Cs=config["cs"],
        defocus=config["df"] + atoms.cell[2, 2] / 2,  # Defocus from mid-plane of sample
        device=device,
    )

    # Set up scan
    scan = abtem.GridScan(
        start=(0, 0),
        end=(unitcell.cell[0, 0], unitcell.cell[1, 1]),
        sampling=probe.ctf.nyquist_sampling
    )

    # Set up detector
    detector = abtem.PixelatedDetector(
        config["max_detection_angle"],
    )

    logger.info("Executing simulation...")
    # Execute simulation
    measurement = probe.scan(potential, scan, detector).compute()

    # Save 4D dataset
    output_dir = pathlib.Path(__file__).parent.parent / "2_output" / "0_simulate_4d_dataset"
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{args.config_label}.pkl"
    with open(output_path, "wb") as f:
        pickle.dump(measurement, f)
    logger.info(f"4D dataset saved to {output_path}")
