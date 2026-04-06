"""
RunPod Serverless Handler for marker-pdf OCR.

Accepts base64-encoded PDFs, runs marker-pdf on GPU, returns markdown.

Input formats:
  Single:  {"pdf_base64": "...", "filename": "optional.pdf"}
  Batch:   {"pdfs": [{"pdf_base64": "...", "filename": "doc1.pdf"}, ...]}
  URL:     {"pdf_url": "https://example.com/file.pdf", "filename": "optional.pdf"}

Output:
  Single:  {"markdown": "...", "filename": "..."}
  Batch:   {"results": [{"markdown": "...", "filename": "..."}, ...]}
"""

import base64
import os
import tempfile
import traceback
import urllib.request

import runpod


def download_pdf(url, dest_path):
    """Download a PDF from a URL."""
    req = urllib.request.Request(url, headers={"User-Agent": "RunPod-OCR/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        with open(dest_path, "wb") as f:
            f.write(resp.read())


def convert_single_pdf(pdf_bytes, filename="document.pdf"):
    """Convert a single PDF to markdown using marker."""
    from marker.converters.pdf import PdfConverter
    from marker.models import create_model_dict

    with tempfile.TemporaryDirectory() as tmpdir:
        input_path = os.path.join(tmpdir, filename)
        with open(input_path, "wb") as f:
            f.write(pdf_bytes)

        converter = PdfConverter(artifact_dict=create_model_dict())
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

            return {"results": results}

        # Single PDF via base64
        elif "pdf_base64" in job_input:
            pdf_bytes = base64.b64decode(job_input["pdf_base64"])
            fname = job_input.get("filename", "document.pdf")
            return convert_single_pdf(pdf_bytes, fname)

        # Single PDF via URL
        elif "pdf_url" in job_input:
            fname = job_input.get("filename", "document.pdf")
            with tempfile.NamedTemporaryFile(suffix=".pdf") as tmp:
                download_pdf(job_input["pdf_url"], tmp.name)
                with open(tmp.name, "rb") as f:
                    pdf_bytes = f.read()
            return convert_single_pdf(pdf_bytes, fname)

        else:
            return {"error": "Input must contain 'pdf_base64', 'pdf_url', or 'pdfs' array"}

    except Exception as e:
        return {"error": str(e), "traceback": traceback.format_exc()}


runpod.serverless.start({"handler": handler})
