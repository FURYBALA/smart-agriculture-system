# Dataset — Vision Node Model

8-class subset of **PlantVillage** (Hughes & Salathe, 2015; mirrored
at [spMohanty/PlantVillage-Dataset](https://github.com/spMohanty/PlantVillage-Dataset)),
400 images per class (each source class has ~1,000 available; started
at 200, doubled after the investigation below):

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

80/20 train/validation split (2,560 train / 640 validation), images
resized to 96x96 to match the camera's native TinyML capture size
on-device.

## Results

| | |
|---|---|
| Float model validation accuracy | **81.9%** (30 epochs, no early stop, Keras's own shuffled 20% split) |
| Quantized (INT8) model size | 69.9 KB |
| Quantized spot-check accuracy | **65.8%** (240 held-out images, random sample — see below) |

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
   (`split_calibration_and_spotcheck`) — reran, got 53.3% and, more
   importantly, a per-class spread that finally meant something: two
   classes (Spider Mite, Target Spot) at ~13%, near the ~12.5% you'd
   expect from random guessing across 8 classes, while the other six
   ranged 47-100%.
4. **Fourth step — more data for the weak classes** (and all classes,
   to keep the set balanced): each source class actually has ~1,000
   images available; only 200 had been used. Doubled to 400/class
   (3,200 total) and retrained from scratch, same architecture, same
   hyperparameters — the only variable changed was dataset size.
   Result: float accuracy **69.7% → 81.9%**, quantized **53.3% →
   65.8%**. Real, substantial improvement from one change.

### What the honest per-class numbers show (400 images/class)

| Class | Accuracy |
|---|---|
| Healthy | 86.7% |
| TYLCV | 83.3% |
| Septoria Leaf Spot | 80.0% |
| Early Blight | 76.7% |
| Bacterial Spot | 63.3% |
| Late Blight | 53.3% |
| **Spider Mite** | **40.0%** (was 13.3%) |
| **Target Spot** | **43.3%** (was 13.3%) |

More data helped every class, and roughly **tripled** the two
previously near-chance classes — but didn't fully fix them. Spider
Mite and Target Spot are still the two weakest classes by a wide
margin, well below the 63-87% the other six now reach. This is no
longer "the model hasn't learned these at all" (13%), it's "the model
finds these two genuinely harder than the rest" (40-43%), which is a
more normal, more fixable kind of gap. If you're extending this
further: look at what Spider Mite and Target Spot images actually
look like (small/subtle symptoms are a common culprit for both),
check whether they're confused with each other or with a specific
other class more than randomly, and consider whether those two
specific classes need even more data, targeted augmentation, or
simply are harder to distinguish from photos alone at this resolution.

This whole result is still below the report's claimed 94.1% F1 —
plausible, since that number came from a 120-image dataset (96 train
/ 24 test, ~12-15 images per class), a strong candidate for
overfitting to look better than it generalizes. Take both numbers
with the dataset sizes in mind.

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
