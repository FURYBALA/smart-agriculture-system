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
| Float model validation accuracy | 69.7% (30 epochs, no early stop, Keras's own shuffled 20% split) |
| Quantized (INT8) model size | 69.9 KB |
| Quantized spot-check accuracy | 53.3% (120 held-out images, random sample — see below) |

Full numbers, including the per-class breakdown: [`ml/models/training_metadata.json`](../ml/models/training_metadata.json).

### The investigation, honestly

The first version of this pipeline showed a suspicious ~18-point drop
between float (69.7%) and quantized (51.7%) accuracy. Three rounds of
actually checking, not assuming:

1. **First guess: the INT8 calibration set was too small** (25
   images/class). Enlarged it 7.4x (to 185/class) and reran. Result:
   **exact same 51.7%**, not a single point of change. Wrong guess,
   ruled out cleanly.
2. **Second check: compare float vs. quantized predictions
   image-by-image** on the same 120-image slice. They agreed on
   119/120 (99.2%) — nearly every prediction, right or wrong, was
   identical between the two. This proved INT8 quantization itself
   is essentially lossless here; it was never the problem.
3. **Third check — the actual bug**: that 120-image "held-out" slice
   was `sorted(files)[-15:]` per class — the alphabetically *last* 15
   filenames, not a random sample. PlantVillage's filenames aren't
   randomly ordered within a class, so this was a biased, non-random
   evaluation set the whole time. Fixed in
   [`ml/scripts/convert_tflite.py`](../ml/scripts/convert_tflite.py)
   to use a seeded random split instead
   (`split_calibration_and_spotcheck`) — reran, got **53.3%** and,
   more importantly, a per-class spread that finally means something.

### What the honest per-class numbers show

| Class | Accuracy |
|---|---|
| Healthy | 100.0% |
| Septoria Leaf Spot | 73.3% |
| TYLCV | 73.3% |
| Early Blight | 60.0% |
| Bacterial Spot | 46.7% |
| Late Blight | 46.7% |
| **Spider Mite** | **13.3%** |
| **Target Spot** | **13.3%** |

This is not uniform degradation and it is not a quantization problem
— it's the model genuinely failing on two specific classes (13.3% is
close to the ~12.5% you'd expect from random guessing across 8
classes), while doing reasonably to well on the other six. If
you're extending this: look at what Spider Mite and Target Spot
images actually look like (small/subtle symptoms are a common
culprit for both), consider more training images or stronger
augmentation specifically for those two classes, and check whether
they're being confused with each other or with "Healthy" acting as a
catch-all.

This whole result is well below the report's claimed 94.1% F1 — that
number came from a 120-image dataset (96 train / 24 test, ~12-15
images per class), which is a strong candidate for overfitting to
look better than it generalizes. Take both numbers with the dataset
sizes in mind.

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
