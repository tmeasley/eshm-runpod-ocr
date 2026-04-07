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
RUN pip install --no-cache-dir marker-pdf runpod

# Pre-download marker model weights during build.
# TORCH_DEVICE=cpu is set ONLY for this RUN step (not persisted as ENV)
# so that at runtime, marker auto-detects the GPU.
RUN TORCH_DEVICE=cpu python -c "\
from marker.models import create_model_dict; \
print('Downloading models...'); \
create_model_dict(); \
print('Models cached successfully.')" || echo "Model pre-download skipped — will download on first run"

COPY handler.py /app/handler.py

# Handler loads models at startup, then serves requests
CMD ["python", "-u", "/app/handler.py"]
