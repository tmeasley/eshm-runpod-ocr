# v13: modern runpod/base with CUDA 12.8, matching torch
FROM runpod/base:1.0.3-cuda1281-ubuntu2204

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Install marker-pdf (pulls its own torch)
RUN pip3 install --no-cache-dir marker-pdf

# Replace CPU torch with CUDA 12.8 version
RUN pip3 install --no-cache-dir \
    torch torchvision \
    --index-url https://download.pytorch.org/whl/cu128

# Verify torch imports and has CUDA tag
RUN python3 -c "import torch; print(f'torch={torch.__version__}, cuda_avail={torch.cuda.is_available()}')"

# Pre-download models
RUN TORCH_DEVICE=cpu python3 -c "from marker.models import create_model_dict; create_model_dict(); print('Models cached')"

COPY handler.py /handler.py

CMD ["python3", "-u", "/handler.py"]
