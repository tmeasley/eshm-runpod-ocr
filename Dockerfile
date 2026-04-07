# v16: pytorch 2.9.1 base (CUDA 12.6, has torch>=2.7 that marker needs)
# constraints.txt pins torch==2.9.1 so marker-pdf can't downgrade to CPU
FROM pytorch/pytorch:2.9.1-cuda12.6-cudnn9-runtime

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

COPY constraints.txt /app/constraints.txt
RUN pip install --no-cache-dir -c /app/constraints.txt marker-pdf runpod

# Verify CUDA torch survived
RUN python -c "import torch; print(f'torch={torch.__version__}, cuda={torch.cuda.is_available()}')"

# Pre-download models
RUN TORCH_DEVICE=cpu python -c "from marker.models import create_model_dict; create_model_dict(); print('Models cached')" || echo "Model cache skipped"

COPY handler.py /app/handler.py

CMD ["python", "-u", "/app/handler.py"]
