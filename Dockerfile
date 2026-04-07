# Use RunPod's official worker base image — guaranteed GPU/CUDA support
FROM runpod/base:0.6.2-cuda11.8.0

# System deps for marker-pdf
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CUDA torch explicitly, then marker-pdf
# v9: runpod/base image + pinned cu118 torch
RUN pip install --no-cache-dir \
    torch==2.1.0+cu118 torchvision==0.16.0+cu118 \
    --index-url https://download.pytorch.org/whl/cu118

RUN pip install --no-cache-dir marker-pdf

# Verify CUDA torch
RUN python -c "import torch; print(f'torch={torch.__version__}, cuda={torch.cuda.is_available()}')"

# Pre-download models (CPU context during build is fine — just caching weights)
RUN TORCH_DEVICE=cpu python -c "from marker.models import create_model_dict; create_model_dict(); print('Models cached')"

COPY handler.py /handler.py

CMD ["python", "-u", "/handler.py"]
