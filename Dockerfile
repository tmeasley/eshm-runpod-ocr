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

# Install marker-pdf and runpod SDK
# Cache bust: v5
RUN pip install --no-cache-dir marker-pdf runpod

# Pre-download marker model weights during build (CPU only — no GPU in build env).
# TORCH_DEVICE is set inline, NOT as ENV, so it does NOT persist to runtime.
RUN TORCH_DEVICE=cpu python -c "\
from marker.models import create_model_dict; \
print('Downloading models to cache...'); \
create_model_dict(); \
print('Done.')"

COPY handler.py /app/handler.py

# At runtime, handler.py detects CUDA and sets TORCH_DEVICE=cuda explicitly.
CMD ["python", "-u", "/app/handler.py"]
