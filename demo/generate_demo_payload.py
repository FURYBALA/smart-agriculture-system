"""
DEMO SCRIPT -- not part of the application or its tests.

Generates a small, deterministic, solid-color synthetic JPEG and a
ready-to-curl payload.json for exercising the live AWS /diagnose
endpoint during a demo. Contains no secrets, no real personal data,
and no real leaf photo -- see docs/demo-assets.md for what this is
and isn't useful for.

Usage:
    pip install Pillow
    python demo/generate_demo_payload.py
    curl -X POST "https://p17huf2s49.execute-api.ap-south-1.amazonaws.com/prod/diagnose" \
        -H "Content-Type: application/json" -d @demo/payload.json
"""
import base64
import io
import json
import sys

try:
    from PIL import Image
except ImportError:
    print("Requires Pillow: pip install Pillow", file=sys.stderr)
    sys.exit(1)

# Deterministic: same color every run, so the demo is reproducible.
DEMO_IMAGE_SIZE = (96, 96)
DEMO_IMAGE_COLOR = (34, 139, 34)  # a plain green square -- NOT a real leaf photo
OUTPUT_PATH = "demo/payload.json"


def main():
    img = Image.new("RGB", DEMO_IMAGE_SIZE, color=DEMO_IMAGE_COLOR)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    payload = {
        "imageBase64": base64.b64encode(buf.getvalue()).decode(),
        "mimeType": "image/jpeg",
    }
    with open(OUTPUT_PATH, "w") as f:
        json.dump(payload, f)
    print(f"Wrote {OUTPUT_PATH} ({len(payload['imageBase64'])} base64 chars)")
    print("This is a solid-color placeholder image, not a real leaf --")
    print("it demonstrates the real pipeline runs, not a meaningful prediction.")


if __name__ == "__main__":
    main()
