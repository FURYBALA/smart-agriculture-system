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

**Known issue, not hidden**: quantization drops accuracy by ~18
points (69.7% -> 51.7%), a larger gap than you'd want in production.

**One fix already tried and ruled out**: the representative dataset
used to calibrate INT8 activation ranges was originally 25
images/class (200 total) — the obvious suspect for under-calibration.
It was increased to 185/class (1,480 total, all training images minus
the 15/class held out for the spot-check) and rerun. Result: **exact
same 51.7%**, not a single point of improvement. That rules out "too
little calibration data" as the cause — something else is behind the
gap, most likely full-integer quantization itself being too aggressive
for one or more layers in this specific architecture (the `Mean` op
from `GlobalAveragePooling2D` and the final `Dense` layer are common
culprits). If you're taking this further, next steps in order of
likely payoff: check **per-class** quantized accuracy (an 18-point
average drop could mean 2-3 classes collapsed to near-zero while
others are fine — very different fix than a uniform degradation),
then consider quantization-aware training if the per-class breakdown
doesn't point to an obvious cause.

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
