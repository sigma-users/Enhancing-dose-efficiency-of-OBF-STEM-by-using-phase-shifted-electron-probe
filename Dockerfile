FROM nvidia/cuda:12.2.2-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# ---- Install Python 3.11 ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python3.11 python3.11-dev python3.11-venv python3.11-distutils && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    rm -rf /var/lib/apt/lists/*

# Make python3 point to python3.11
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# ---- Project root ----
WORKDIR /build/obfweight

# ---- Copy project files ----
COPY . .

RUN python3.11 -m ensurepip --upgrade || true && \
    python3.11 -m pip install --upgrade pip setuptools wheel && \
    python3.11 -m pip install -r requirements.txt

# ---- Build CUDA static library ----
RUN make

# ---- Build Python extension (depends on libobfweight.a) ----
WORKDIR /build/obfweight/python

RUN python3.11 -m pip install --no-build-isolation -e .

# ---- Final working directory ----
WORKDIR /workspace/pipeline

CMD ["/bin/bash"]
