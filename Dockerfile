# v14: simplest possible — just install marker-pdf, let it pull its own torch
# Don't fight torch versions. Let marker pick what it needs.
# At runtime on RunPod GPU, torch.cuda.is_available() should be True
# if the CUDA drivers are present (which runpod/base provides).
FROM runpod/base:1.0.3-cuda1281-ubuntu2204

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir marker-pdf runpod

# Don't verify CUDA during build (no GPU in build env) — just check torch imports
RUN python3 -c "import torch; print(f'torch={torch.__version__}')"
RUN python3 -c "import marker; print('marker OK')"

# Pre-download models (CPU during build is expected)
RUN TORCH_DEVICE=cpu python3 -c "from marker.models import create_model_dict; create_model_dict(); print('Models cached')"

COPY handler.py /handler.py

CMD ["python3", "-u", "/handler.py"]
