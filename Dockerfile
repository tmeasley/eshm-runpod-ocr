FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

WORKDIR /app

# System deps for marker-pdf
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

# Install marker-pdf and runpod SDK
RUN pip install --no-cache-dir marker-pdf runpod

# Pre-download all marker models into the image (critical for cold-start speed)
RUN python -c "from marker.models import create_model_dict; create_model_dict()"

COPY handler.py /app/handler.py

CMD ["python", "-u", "/app/handler.py"]
