# RunPod's official worker base — confirmed GPU/CUDA support for serverless
FROM runpod/base:0.3.0-cuda11.8.0

# System deps for marker-pdf
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# v10: correct runpod/base tag
# Install CUDA torch, then marker-pdf
RUN pip install --no-cache-dir \
    torch==2.1.0+cu118 torchvision==0.16.0+cu118 \
    --index-url https://download.pytorch.org/whl/cu118

RUN pip install --no-cache-dir marker-pdf

# Verify torch has CUDA support baked in
RUN python -c "import torch; v=torch.__version__; print(f'torch={v}'); assert 'cu' in v, f'CPU-only torch: {v}'"

# Pre-download models
RUN TORCH_DEVICE=cpu python -c "from marker.models import create_model_dict; create_model_dict(); print('Models cached')"

COPY handler.py /handler.py

CMD ["python", "-u", "/handler.py"]
