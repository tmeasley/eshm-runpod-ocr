"""
RunPod Serverless Handler for marker-pdf OCR.
v8: Force marker settings to use CUDA after import.
"""

import base64
import os
import sys
import tempfile
import traceback
import urllib.request

import torch
import runpod

# Detect device
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
DTYPE = torch.bfloat16 if DEVICE == "cuda" else torch.float32

print(f"[handler] torch.cuda.is_available() = {torch.cuda.is_available()}", flush=True)
print(f"[handler] Device: {DEVICE}, Dtype: {DTYPE}", flush=True)
if torch.cuda.is_available():
    print(f"[handler] GPU: {torch.cuda.get_device_name(0)}", flush=True)
print(f"[handler] Torch version: {torch.__version__}", flush=True)

# Set env var BEFORE importing marker (marker reads it at import time via pydantic)
os.environ["TORCH_DEVICE"] = DEVICE

# Now import marker
from marker.converters.pdf import PdfConverter
from marker.models import create_model_dict
from marker.settings import settings as marker_settings

# Force override marker's settings object directly
marker_settings.TORCH_DEVICE = DEVICE
print(f"[handler] marker_settings.TORCH_DEVICE = {marker_settings.TORCH_DEVICE}", flush=True)
print(f"[handler] marker_settings.TORCH_DEVICE_MODEL = {marker_settings.TORCH_DEVICE_MODEL}", flush=True)
print(f"[handler] marker_settings.MODEL_DTYPE = {marker_settings.MODEL_DTYPE}", flush=True)

# Load models
print("[handler] Loading models...", flush=True)
MODEL_DICT = create_model_dict()
print("[handler] Models loaded. Ready for jobs.", flush=True)


def download_pdf(url, dest_path):
    req = urllib.request.Request(url, headers={"User-Agent": "RunPod-OCR/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        with open(dest_path, "wb") as f:
            f.write(resp.read())


def convert_single_pdf(pdf_bytes, filename="document.pdf"):
    with tempfile.TemporaryDirectory() as tmpdir:
        input_path = os.path.join(tmpdir, filename)
        with open(input_path, "wb") as f:
            f.write(pdf_bytes)
        converter = PdfConverter(artifact_dict=MODEL_DICT)
        rendered = converter(input_path)
        return {"markdown": rendered.markdown, "filename": filename}


def handler(job):
    job_input = job["input"]

    # Diagnostic mode
    if job_input.get("diagnostic"):
        return {
            "torch_version": torch.__version__,
            "cuda_available": torch.cuda.is_available(),
            "device": DEVICE,
            "gpu_name": torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none",
            "marker_device": marker_settings.TORCH_DEVICE,
            "marker_device_model": marker_settings.TORCH_DEVICE_MODEL,
            "marker_dtype": str(marker_settings.MODEL_DTYPE),
        }

    try:
        if "pdfs" in job_input:
            results = []
            for i, item in enumerate(job_input["pdfs"]):
                fname = item.get("filename", f"document_{i+1}.pdf")
                if "pdf_base64" in item:
                    pdf_bytes = base64.b64decode(item["pdf_base64"])
                elif "pdf_url" in item:
                    with tempfile.NamedTemporaryFile(suffix=".pdf") as tmp:
                        download_pdf(item["pdf_url"], tmp.name)
                        with open(tmp.name, "rb") as f:
                            pdf_bytes = f.read()
                else:
                    results.append({"filename": fname, "error": "No pdf_base64 or pdf_url"})
                    continue
                result = convert_single_pdf(pdf_bytes, fname)
                results.append(result)
            return {"results": results, "device": DEVICE}

        elif "pdf_base64" in job_input:
            pdf_bytes = base64.b64decode(job_input["pdf_base64"])
            fname = job_input.get("filename", "document.pdf")
            result = convert_single_pdf(pdf_bytes, fname)
            result["device"] = DEVICE
            return result

        elif "pdf_url" in job_input:
            fname = job_input.get("filename", "document.pdf")
            with tempfile.NamedTemporaryFile(suffix=".pdf") as tmp:
                download_pdf(job_input["pdf_url"], tmp.name)
                with open(tmp.name, "rb") as f:
                    pdf_bytes = f.read()
            result = convert_single_pdf(pdf_bytes, fname)
            result["device"] = DEVICE
            return result

        else:
            return {"error": "Input must contain 'pdf_base64', 'pdf_url', or 'pdfs' array"}

    except Exception as e:
        return {"error": str(e), "traceback": traceback.format_exc(), "device": DEVICE}


runpod.serverless.start({"handler": handler})
