FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

WORKDIR /app

# System deps for marker-pdf (OpenCV, rendering libs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CUDA-enabled PyTorch FIRST (marker-pdf's pip install can overwrite with CPU torch)
# Then install marker-pdf without deps to avoid torch replacement, then its other deps
# v6: force CUDA torch
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu118
RUN pip install --no-cache-dir marker-pdf runpod

# Verify CUDA torch is present
RUN python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'Torch version: {torch.__version__}')"

# Pre-download marker model weights during build (CPU-only context during build is fine)
RUN TORCH_DEVICE=cpu python -c "\
from marker.models import create_model_dict; \
print('Downloading models...'); \
create_model_dict(); \
print('Models cached.')"

COPY handler.py /app/handler.py

CMD ["python", "-u", "/app/handler.py"]
