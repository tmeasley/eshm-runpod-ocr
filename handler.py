"""
RunPod Serverless Handler for marker-pdf OCR.

Accepts base64-encoded PDFs, runs marker-pdf on GPU, returns markdown.

Input formats:
  Single:  {"pdf_base64": "...", "filename": "optional.pdf"}
  Batch:   {"pdfs": [{"pdf_base64": "...", "filename": "doc1.pdf"}, ...]}
  URL:     {"pdf_url": "https://example.com/file.pdf", "filename": "optional.pdf"}

Output:
  Single:  {"markdown": "...", "filename": "...", "device": "..."}
  Batch:   {"results": [{"markdown": "...", "filename": "..."}, ...], "device": "..."}
"""

import base64
import os
import sys
import tempfile
import traceback
import urllib.request

import torch
import runpod

# Force CUDA if available
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
print(f"[handler] PyTorch device: {DEVICE}", flush=True)
print(f"[handler] CUDA available: {torch.cuda.is_available()}", flush=True)
if torch.cuda.is_available():
    print(f"[handler] GPU: {torch.cuda.get_device_name(0)}", flush=True)
    print(f"[handler] VRAM: {torch.cuda.get_device_properties(0).total_mem / 1e9:.1f} GB", flush=True)

# Explicitly set device for marker
os.environ["TORCH_DEVICE"] = DEVICE

# Load models once at startup
print("[handler] Loading marker models...", flush=True)
from marker.converters.pdf import PdfConverter
from marker.models import create_model_dict

MODEL_DICT = create_model_dict()
print("[handler] Models loaded successfully.", flush=True)


def download_pdf(url, dest_path):
    """Download a PDF from a URL."""
    req = urllib.request.Request(url, headers={"User-Agent": "RunPod-OCR/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        with open(dest_path, "wb") as f:
            f.write(resp.read())


def convert_single_pdf(pdf_bytes, filename="document.pdf"):
    """Convert a single PDF to markdown using marker."""
    with tempfile.TemporaryDirectory() as tmpdir:
        input_path = os.path.join(tmpdir, filename)
        with open(input_path, "wb") as f:
            f.write(pdf_bytes)

        converter = PdfConverter(artifact_dict=MODEL_DICT)
        rendered = converter(input_path)
        markdown = rendered.markdown

        return {"markdown": markdown, "filename": filename}


def handler(job):
    """Process OCR job."""
    job_input = job["input"]

    try:
        # Batch mode
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

        # Single PDF via base64
        elif "pdf_base64" in job_input:
            pdf_bytes = base64.b64decode(job_input["pdf_base64"])
            fname = job_input.get("filename", "document.pdf")
            result = convert_single_pdf(pdf_bytes, fname)
            result["device"] = DEVICE
            return result

        # Single PDF via URL
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
