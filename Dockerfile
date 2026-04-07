# RunPod's official serverless worker base
FROM runpod/base:0.3.0-cuda11.8.0

# System deps for marker-pdf
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# v11: fix python → python3
RUN pip3 install --no-cache-dir \
    torch==2.1.0+cu118 torchvision==0.16.0+cu118 \
    --index-url https://download.pytorch.org/whl/cu118

RUN pip3 install --no-cache-dir marker-pdf

# Verify CUDA torch
RUN python3 -c "import torch; v=torch.__version__; print(f'torch={v}'); assert 'cu' in v, f'CPU-only: {v}'"

# Pre-download models
RUN TORCH_DEVICE=cpu python3 -c "from marker.models import create_model_dict; create_model_dict(); print('Models cached')"

COPY handler.py /handler.py

CMD ["python3", "-u", "/handler.py"]
