# eshm-runpod-ocr

RunPod Serverless handler for GPU-accelerated PDF-to-Markdown conversion using [marker-pdf](https://github.com/VikParuchuri/marker).

## Deploy

1. Connect this repo to RunPod Serverless (GitHub integration)
2. GPU: RTX 4090 (24GB), Flex workers, min 0 / max 2
3. Idle timeout: 5s

## Usage

```bash
# Single PDF (base64)
curl -X POST "https://api.runpod.ai/v2/ENDPOINT_ID/runsync" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"input\": {\"pdf_base64\": \"$(base64 -i file.pdf)\", \"filename\": \"file.pdf\"}}"

# Single PDF (URL)
curl -X POST "https://api.runpod.ai/v2/ENDPOINT_ID/runsync" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"input": {"pdf_url": "https://example.com/file.pdf", "filename": "file.pdf"}}'
```
