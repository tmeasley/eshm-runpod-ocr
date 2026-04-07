# v15: pytorch base (has CUDA torch) + constraints to prevent torch downgrade
FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Constraints file prevents pip from replacing the CUDA torch with CPU torch
COPY constraints.txt /app/constraints.txt
RUN pip install --no-cache-dir -c /app/constraints.txt marker-pdf runpod

# Verify the base image's CUDA torch survived
RUN python -c "import torch; print(f'torch={torch.__version__}, cuda={torch.cuda.is_available()}')"

# Pre-download models
RUN TORCH_DEVICE=cpu python -c "from marker.models import create_model_dict; create_model_dict(); print('Models cached')" || echo "Model cache skipped"

COPY handler.py /app/handler.py

CMD ["python", "-u", "/app/handler.py"]
