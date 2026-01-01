from setuptools import setup, Extension
import numpy
import os

this_dir = os.path.abspath(os.path.dirname(__file__))
root_dir = os.path.abspath(os.path.join(this_dir, ".."))

ext = Extension(
    name="obfweight.obf_cuda",
    sources=[os.path.join(this_dir, "obfweight", "_obf_cuda.cpp")],
    include_dirs=[
        numpy.get_include(),
        os.path.join(root_dir, "include"),
    ],
    libraries=[
        "obfweight",
        "cudart",
    ],
    library_dirs=[
        root_dir,                 # libobfweight.a
        "/usr/local/cuda/lib64",  # libcudart.so
    ],
    extra_link_args=[
        "-std=c++17",
        "-Wl,-rpath,/usr/local/cuda/lib64",
    ],
    language="c++",
)

setup(
    name="obfweight",
    version="0.1.0",
    description="CUDA-based OBF weight computation",
    packages=["obfweight"],
    package_dir={"obfweight": "obfweight"},
    ext_modules=[ext],
)
