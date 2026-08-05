"""
Download the 8-class tomato-leaf subset of PlantVillage from the
public GitHub mirror (spMohanty/PlantVillage-Dataset) -- no
authentication or Kaggle account required. See docs/dataset.md for
the class mapping and the Bacterial Speck -> Bacterial Spot
substitution this makes.

Usage:
    python download_dataset.py
"""
import pathlib
import urllib.request
import urllib.parse
import urllib.error
import json

REPO = "spMohanty/PlantVillage-Dataset"
IMAGES_PER_CLASS = 400  # each class has ~1000 available; 200 was the
# first attempt -- doubled after the trained model showed near-chance
# accuracy (~13%) on 2 of 8 classes (Spider Mite, Target Spot), a
# likely symptom of too little data for those specific classes. See
# docs/dataset.md for the accuracy investigation this follows from.

CLASSES = {
    "Tomato___healthy": "Healthy",
    "Tomato___Early_blight": "Early_Blight",
    "Tomato___Late_blight": "Late_Blight",
    "Tomato___Septoria_leaf_spot": "Septoria_Leaf_Spot",
    "Tomato___Spider_mites Two-spotted_spider_mite": "Spider_Mite",
    "Tomato___Bacterial_spot": "Bacterial_Spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": "TYLCV",
    "Tomato___Target_Spot": "Target_Spot",
}

DATA_DIR = pathlib.Path(__file__).resolve().parent.parent / "data" / "raw"


def list_download_urls(class_name: str) -> list[str]:
    encoded = urllib.parse.quote(class_name)
    api_url = f"https://api.github.com/repos/{REPO}/contents/raw/color/{encoded}"
    req = urllib.request.Request(api_url, headers={"User-Agent": "smart-agriculture-system"})
    with urllib.request.urlopen(req) as resp:
        entries = json.load(resp)
    return [e["download_url"] for e in entries if e["type"] == "file"]


def download(url: str, dest: pathlib.Path):
    req = urllib.request.Request(url, headers={"User-Agent": "smart-agriculture-system"})
    with urllib.request.urlopen(req) as resp, open(dest, "wb") as f:
        f.write(resp.read())


def main():
    for class_name, short_name in CLASSES.items():
        out_dir = DATA_DIR / short_name
        out_dir.mkdir(parents=True, exist_ok=True)

        print(f"Listing {class_name} ...")
        urls = list_download_urls(class_name)[:IMAGES_PER_CLASS]

        for i, url in enumerate(urls, start=1):
            dest = out_dir / f"{i:04d}.jpg"
            if dest.exists():
                continue
            try:
                download(url, dest)
            except urllib.error.URLError as e:
                print(f"  failed: {url} ({e})")

        count = len(list(out_dir.glob("*.jpg")))
        print(f"{short_name}: {count} images in {out_dir}")


if __name__ == "__main__":
    main()
