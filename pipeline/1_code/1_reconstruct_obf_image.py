# -*- coding: utf-8 -*-
"""Reconstruct OBF image from 4D STEM dataset.

This script reconstructs an OBF image from a simulated 4D STEM dataset based on a given configuration.
The configuration is provided in a JSON file located in the `pipeline/0_input/1_reconstruct_obf_image` directory.
The result is saved as a numpy array and PNG image in the `pipeline/2_output/1_reconstruct_obf_image` directory.
"""
import argparse
import json
import pathlib
import pickle
import ase.io
import numpy as np
import obfweight
from typing import TYPE_CHECKING
from abtem.core.energy import energy2wavelength
from PIL import Image
from logging import getLogger, basicConfig, INFO

if TYPE_CHECKING:
    from abtem import DiffractionPatterns


basicConfig(level=INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = getLogger(__name__)


def fwhm_to_sigma(fwhm: float) -> float:
    """Convert FWHM to standard deviation (sigma) for Gaussian.

    Args:
        fwhm (float): Full width at half maximum.
    Returns:
        float: Standard deviation (sigma)."""
    return fwhm / (2 * np.sqrt(2 * np.log(2)))


def alpha_to_k(alpha: float, wavelength: float) -> float:
    """Convert semi-angle alpha to spatial frequency k.

    Args:
        alpha (float): Semi-angle in radians.
        wavelength (float): Wavelength in milli-radians.
    Returns:
        float: Spatial frequency k in 1/Angstroms."""
    return alpha * 1e-3 / wavelength


def calc_reciprocal_safely(arr: np.ndarray, epsilon: float = 1e-5) -> np.ndarray:
    """Calculate reciprocal of an array safely to avoid division by zero.

    Args:
        arr (np.ndarray): Input array.
        epsilon (float, optional): Small value to avoid division by zero. Defaults to 1e-5.
    Returns:
        np.ndarray: Reciprocal of the input array.
    """
    return 1.0 / (arr + epsilon * (arr == 0))


if __name__ == "__main__":
    argparser = argparse.ArgumentParser(description="Reconstruct OBF image from 4D dataset")
    argparser.add_argument("reconstruction_config_label", type=str, help="Configuration label")

    args = argparser.parse_args()
    reconstruction_config_label = args.reconstruction_config_label
    reconstruction_config_path = (
        pathlib.Path(__file__).parent.parent
        / "0_input"
        / "1_reconstruct_obf_image"
        / f"{reconstruction_config_label}.json"
    )
    # Load reconstruction config
    if not reconstruction_config_path.exists():
        raise FileNotFoundError(f"Reconstruction config file not found: {reconstruction_config_path}")

    logger.info(f"Starting OBF image reconstruction with config: {reconstruction_config}")
    with open(reconstruction_config_path) as f:
        reconstruction_config = json.load(f)

    # Load simulation config
    simulation_config_label = reconstruction_config["simulation_config_label"]
    simulation_config_path = (
        pathlib.Path(__file__).parent.parent
        / "0_input"
        / "0_simulate_4d_dataset"
        / f"{simulation_config_label}.json"
    )
    if not simulation_config_path.exists():
        raise FileNotFoundError(f"Simulation config file not found: {simulation_config_path}")
    with open(simulation_config_path) as f:
        simulation_config = json.load(f)

    dose = reconstruction_config["dose"]
    fwhm = reconstruction_config["fwhm"]
    tile_size = reconstruction_config["tile_size"]
    cs = simulation_config["cs"]
    df = simulation_config["df"]
    energy = simulation_config["energy"]
    semiangle_cutoff = simulation_config["semiangle_cutoff"]
    wavelength = energy2wavelength(energy)
    seed = reconstruction_config.get("seed", None)

    # Load structure to calculate thickness
    structure_path = (
        pathlib.Path(__file__).parent.parent
        / "0_input"
        / "structures"
        / simulation_config["structure"]
    )
    if not structure_path.exists():
        raise FileNotFoundError(f"Structure file not found: {structure_path}")
    structure = ase.io.read(structure_path)
    thickness = structure.get_cell()[2, 2]

    logger.info("Loading 4D dataset...")
    # Load 4D dataset
    dataset_path = (
        pathlib.Path(__file__).parent.parent
        / "2_output"
        / "0_simulate_4d_dataset"
        / f"{simulation_config_label}.pkl"
    )
    if not dataset_path.exists():
        raise FileNotFoundError(f"4D dataset file not found: {dataset_path}")
    with open(dataset_path, "rb") as f:
        dataset: "DiffractionPatterns" = pickle.load(f)

    logger.info("Preprocessing 4D dataset...")
    # Preprocess 4D dataset (add source size, tile scan, and noise)
    dataset = dataset.gaussian_source_size(sigma=fwhm_to_sigma(fwhm)).tile_scan(tile_size)

    if dose != "inf":
        dataset = dataset.poisson_noise(dose_per_area=dose, seed=seed)

    # Extract coordinates and sampling
    nx, ny, nkx, nky = dataset.array.shape
    dx = dataset.ensemble_axes_metadata[0].sampling
    dy = dataset.ensemble_axes_metadata[1].sampling
    qx = np.fft.fftfreq(nx, d=dx)
    qy = np.fft.fftfreq(ny, d=dy)
    dqx = qx[1] - qx[0]
    dqy = qy[1] - qy[0]
    qx_min = qx.min()
    qy_min = qy.min()

    kx_min, ky_min = dataset.offset
    dkx, dky = dataset.sampling

    logger.info("Calculating OBF weights...")
    # Calculate OBF weights
    weight = obfweight.weight(
        qx_min,
        dqx,
        nx,
        qy_min,
        dqy,
        ny,
        kx_min,
        dkx,
        nkx,
        ky_min,
        dky,
        nky,
        wavelength,
        alpha_to_k(semiangle_cutoff, wavelength),
        thickness,
        df,
        cs,
    )
    weight = np.fft.ifftshift(weight, axes=(0, 1))
    # normalization factor
    k = calc_reciprocal_safely(np.sqrt(np.sum(np.abs(weight) ** 2, axis=(2, 3))))

    # Reconstruct OBF image
    g = np.fft.fft2(dataset.array, axes=(0, 1))
    obf_img = np.fft.ifft2(k * np.sum(g * np.conjugate(weight), axis=(2, 3)))

    logger.info("Saving reconstructed OBF image...")
    # Save reconstructed OBF image
    output_dir = (
        pathlib.Path(__file__).parent.parent
        / "2_output"
        / "1_reconstruct_obf_image"
    )

    # Save as numpy array
    npy_dir = output_dir / "npy"
    npy_dir.mkdir(parents=True, exist_ok=True)
    np.save(npy_dir / f"{reconstruction_config_label}_obf_image.npy", obf_img)
    logger.info(f"Reconstructed OBF image saved to {npy_dir / f'{reconstruction_config_label}_obf_image.npy'}")

    # Save as png image
    image_dir = output_dir / "images"
    image_dir.mkdir(parents=True, exist_ok=True)
    img = obf_img.imag
    img = (255 * (img - img.min()) / (img.max() - img.min())).astype(np.uint8)
    Image.fromarray(img).save(image_dir / f"{reconstruction_config_label}_obf_image.png")
    logger.info(f"Reconstructed OBF image saved to {image_dir / f'{reconstruction_config_label}_obf_image.png'}")
