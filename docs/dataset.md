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
finds these two genuinely harder than the rest" (40-43%).

### Fifth step — tried, and rejected based on the result

Obvious next idea: since each source class has ~1,000 images
available, max out data for just the two weak classes (1,000 each)
while leaving the other six at 400, and retrain. Tried it. **The
result was worse, not better, and is not shipped:**

| Class | 400/class (shipped) | 1,000/class for Spider Mite + Target Spot only |
|---|---|---|
| Bacterial Spot | 63.3% | 40.0% (**-23.3**) |
| Early Blight | 76.7% | 76.7% |
| Healthy | 86.7% | 90.0% |
| Late Blight | 53.3% | 36.7% (**-16.7**) |
| Septoria Leaf Spot | 80.0% | 90.0% |
| Spider Mite | 40.0% | 40.0% (no change, despite +600 images) |
| TYLCV | 83.3% | 76.7% (**-6.7**) |
| Target Spot | 43.3% | 53.3% (+10.0) |
| **Overall** | **65.8%** | **62.9%** |

Skewing the dataset 2.5x toward two classes measurably hurt three of
the six classes whose data never changed (Bacterial Spot and Late
Blight worst-hit), while only partially helping the intended targets
— Target Spot gained 10 points, but Spider Mite gained nothing at all
from 600 extra images. Most likely cause: with `categorical_crossentropy`
and no class weighting, overrepresenting two classes shifts the
model's decision boundaries in their favor at other classes' expense,
which is exactly what the drop pattern looks like. **The 400/class
balanced model (this repo's shipped version) stayed the better
result**, and this asymmetric-data experiment was reverted rather
than merged.

### Sixth step — also tried, also rejected, worse than the fifth

Next candidate: class-weighted loss. Same balanced 400/class dataset
(the extra Spider Mite / Target Spot images from step five were moved
out, not deleted, and the data restored to exactly 400/class first —
isolating loss weighting as the only variable this time). Gave Spider
Mite and Target Spot 2x weight in `categorical_crossentropy` via
Keras's `class_weight`, otherwise identical architecture and
hyperparameters. **Result: worse than either prior version, including
for the two classes it was meant to help:**

| Class | 400/class (shipped) | 2x class-weighted (same data) |
|---|---|---|
| Bacterial Spot | 63.3% | 30.0% (-33.3) |
| Early Blight | 76.7% | 53.3% (-23.4) |
| Healthy | 86.7% | 80.0% (-6.7) |
| Late Blight | 53.3% | 20.0% (-33.3) |
| Septoria Leaf Spot | 80.0% | 90.0% (+10.0) |
| **Spider Mite** | **40.0%** | **16.7% (-23.3)** |
| TYLCV | 83.3% | 76.7% (-6.6) |
| **Target Spot** | **43.3%** | **30.0% (-13.3)** |
| **Overall** | **65.8%** | **49.6%** |

Both target classes got *worse*, not better — the opposite of the
hypothesis. Validation accuracy oscillated heavily between epochs
during training (e.g. 0.68 → 0.48 → 0.59 → 0.57 → 0.52 across five
consecutive epochs) rather than converging, which points at 2x
weighting on 2 of 8 classes destabilizing optimization at this
dataset size and learning rate, not a validated fix. This result also
argues against "class imbalance, not class difficulty" as the
explanation for step five's failure — if that were the whole story,
correcting for it via loss weighting instead of data skew should have
helped, and it didn't.

**The 400/class balanced model, no class weighting, remains the best
result and the one shipped.** Two different, reasonable attempts to
close the Spider Mite / Target Spot gap have now been tried and both
made things worse — that's a real signal this specific gap won't move
with training-recipe tweaks alone.

### Seventh step — root cause, via confusion matrix

Rather than guess a third training-recipe tweak, looked at what the
model actually confuses these two classes *with*. Ran the full 8x8
confusion matrix on a held-out sample (30 images/class) and it's not
what "two hard classes" usually looks like:

- **Spider Mite**: only 4/30 misclassifications go to Target Spot (the
  other weak class) — but **14/30 go to Septoria Leaf Spot**.
- **Target Spot**: only 1/30 goes to Spider Mite — but **16/30 go to
  Septoria Leaf Spot**.
- **Septoria Leaf Spot** is meanwhile the single best-predicted class
  in the whole model (29/30, essentially no errors of its own).

So Spider Mite and Target Spot aren't confused with each other, and
they're not scattered randomly across all 8 classes either (which
would suggest generically weak, noisy features). They're both
specifically pulled into one look-alike class. All three are
leaf-**spot**-pattern diseases visually, and at 96x96 resolution the
model appears to have learned an overly broad "spotted leaf" feature
that Septoria Leaf Spot dominates, absorbing the other two spot-type
diseases into it. That's a genuine architecture/resolution limitation,
not something more data or loss weighting on the same 4-conv-block
CNN was ever going to fix — which is consistent with why both of the
last two experiments failed.

**Where this leaves it**: closing this gap further needs a
qualitatively different intervention than what's been tried — e.g. a
model with more capacity or a different receptive-field structure
specifically for texture/pattern discrimination, a higher input
resolution than 96x96 (trades off against the ESP32-CAM's memory
budget — see `docs/bring-up-checklist.md`), or explicit
Septoria-vs-Spider-Mite/Target-Spot hard-negative training. None of
that is a quick retrain, so it's documented here as the identified
cause rather than attempted blind. The shipped model's honest
numbers (81.9% float / 65.8% quantized, this specific confusion
pattern) are the final result of this investigation.

This whole result is still below the report's claimed 94.1% F1 —
plausible, since that number came from a 120-image dataset (96 train
/ 24 test, ~12-15 images per class), a strong candidate for
overfitting to look better than it generalizes. Take both numbers
with the dataset sizes in mind.

**Reproducibility note**: a retrain during the confusion-matrix
diagnostic, using the identical script, data, and seed as the shipped
model, came out at 74.5% validation accuracy — about 7 points below
the shipped model's 81.9% on the same setup. Both `SEED=42` values
control the *dataset* shuffle/split, not TensorFlow's own op-level
nondeterminism on CPU (thread scheduling, floating-point reduction
order), so different runs can land in different local optima even
with everything else held constant. Don't be surprised if you retrain
from these scripts and don't land on exactly 81.9% — the qualitative
findings above (which classes are weak, what they're confused with)
are more load-bearing than the exact decimal.

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
