# Dataset — Vision Node Model

8-class subset of **PlantVillage** (Hughes & Salathe, 2015; mirrored
at [spMohanty/PlantVillage-Dataset](https://github.com/spMohanty/PlantVillage-Dataset)),
~200 images per class:

| Report's class name | PlantVillage source class | Notes |
|---|---|---|
| Healthy | `Tomato___healthy` | |
| Early Blight | `Tomato___Early_blight` | |
| Late Blight | `Tomato___Late_blight` | |
| Septoria Leaf Spot | `Tomato___Septoria_leaf_spot` | |
| Spider Mite | `Tomato___Spider_mites Two-spotted_spider_mite` | |
| Bacterial Speck | `Tomato___Bacterial_spot` | **Substitute** — PlantVillage has no Bacterial Speck class; Bacterial Spot is the closest available proxy (different pathogen, similar presentation) |
| TYLCV | `Tomato___Tomato_Yellow_Leaf_Curl_Virus` | |
| Target Spot | `Tomato___Target_Spot` | |

80/20 train/validation split (1,280 train / 320 validation), images
resized to 96x96 to match the camera's native TinyML capture size
on-device.

## Results

| | |
|---|---|
| Float model validation accuracy | 69.7% (30 epochs, no early stop) |
| Quantized (INT8) model size | 69.9 KB |
| Quantized spot-check accuracy | 51.7% (120 held-out images) |

Full numbers: [`ml/models/training_metadata.json`](../ml/models/training_metadata.json).

**Known issue, not hidden**: quantization dropped accuracy by ~18
points (69.7% -> 51.7%), a larger gap than you'd want in production.
The representative dataset used for calibrating INT8 activation
ranges was 25 images/class (200 total) — likely too little for an
8-class, 4-conv-block model to calibrate well. If you're taking this
further: try a larger/full representative dataset first, then check
per-class quantized accuracy (an 18-point average drop could mean a
few classes collapsed almost entirely while others held up fine), and
consider quantization-aware training if that's not enough.

This is well below the report's claimed 94.1% F1 — that number came
from a 120-image dataset (96 train / 24 test, ~12-15 images per
class), which is a strong candidate for overfitting to look better
than it generalizes. Take both numbers with the dataset sizes in
mind.

## Citation

> Hughes, D.P. and Salathe, M., 2015. *An open access repository of
> images on plant health to enable the development of mobile disease
> diagnostics.* arXiv:1511.08060.

## Re-downloading

```bash
cd ml
pip install -r requirements.txt
python scripts/download_dataset.py
```
