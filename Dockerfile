FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

WORKDIR /app

# Install Python 3.10 + system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 python3-pip python3.10-dev \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && rm -rf /var/lib/apt/lists/*

# Install CUDA PyTorch first, then marker-pdf
# v7: use nvidia/cuda base + explicit cu118 torch
RUN pip install --no-cache-dir \
    torch==2.1.0+cu118 torchvision==0.16.0+cu118 \
    --index-url https://download.pytorch.org/whl/cu118

RUN pip install --no-cache-dir marker-pdf runpod

# Verify torch sees CUDA
RUN python -c "import torch; assert 'cu' in torch.__version__, f'CPU torch installed: {torch.__version__}'; print(f'Torch {torch.__version__} with CUDA support')"

# Pre-download models
RUN TORCH_DEVICE=cpu python -c "\
from marker.models import create_model_dict; \
print('Downloading models...'); \
create_model_dict(); \
print('Models cached.')"

COPY handler.py /app/handler.py

CMD ["python", "-u", "/app/handler.py"]
