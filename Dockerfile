FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# ---- Install system deps ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# ---- Project root ----
WORKDIR /workspace/obfweight

# ---- Copy project files ----
COPY . .

RUN pip3 install --upgrade pip setuptools wheel \
    && pip3 install -r requirements.txt

# ---- Build CUDA static library ----
RUN make

# ---- Build Python extension (depends on libobfweight.a) ----
WORKDIR /workspace/obfweight/python

RUN pip3 install --no-build-isolation -e .

# ---- Final working directory ----
WORKDIR /workspace/obfweight

CMD ["/bin/bash"]
