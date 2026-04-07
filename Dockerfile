FROM runpod/base:0.3.0-cuda11.8.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# v12: install marker-pdf first, THEN force CUDA torch on top
RUN pip3 install --no-cache-dir marker-pdf

# Force reinstall CUDA torch AFTER marker-pdf (marker pulls CPU torch as dep)
RUN pip3 install --no-cache-dir --force-reinstall \
    torch==2.1.0+cu118 torchvision==0.16.0+cu118 \
    --index-url https://download.pytorch.org/whl/cu118

# Verify
RUN python3 -c "import torch; print(f'torch={torch.__version__}, cuda={torch.cuda.is_available()}')"

# Pre-download models
RUN TORCH_DEVICE=cpu python3 -c "from marker.models import create_model_dict; create_model_dict(); print('Models cached')"

COPY handler.py /handler.py

CMD ["python3", "-u", "/handler.py"]
