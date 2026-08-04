"""
Train the 8-class tomato leaf disease CNN, sized to be deployable on
a microcontroller after TFLite INT8 quantization.

Usage:
    python train.py
"""
import pathlib
import json

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

IMG_SIZE = (96, 96)
BATCH_SIZE = 32
EPOCHS = 30
SEED = 42

DATA_DIR = pathlib.Path(__file__).resolve().parent.parent / "data" / "raw"
MODELS_DIR = pathlib.Path(__file__).resolve().parent.parent / "models"
MODELS_DIR.mkdir(parents=True, exist_ok=True)


def build_datasets():
    train_ds = keras.utils.image_dataset_from_directory(
        DATA_DIR, validation_split=0.2, subset="training", seed=SEED,
        image_size=IMG_SIZE, batch_size=BATCH_SIZE, label_mode="categorical",
    )
    val_ds = keras.utils.image_dataset_from_directory(
        DATA_DIR, validation_split=0.2, subset="validation", seed=SEED,
        image_size=IMG_SIZE, batch_size=BATCH_SIZE, label_mode="categorical",
    )
    class_names = train_ds.class_names

    augment = keras.Sequential([
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.08),
        layers.RandomZoom(0.1),
        layers.RandomContrast(0.1),
    ])
    train_ds = train_ds.map(lambda x, y: (augment(x, training=True), y))

    normalize = layers.Rescaling(1.0 / 255)
    train_ds = train_ds.map(lambda x, y: (normalize(x), y)).prefetch(tf.data.AUTOTUNE)
    val_ds = val_ds.map(lambda x, y: (normalize(x), y)).prefetch(tf.data.AUTOTUNE)
    return train_ds, val_ds, class_names


def build_model(num_classes):
    # Four conv blocks (bigger than a 3-class model needs) since 8
    # visually-similar leaf diseases need more capacity to separate --
    # still small enough to fit an ESP32-CAM after INT8 quantization.
    model = keras.Sequential([
        layers.Input(shape=(*IMG_SIZE, 3)),
        layers.Conv2D(16, 3, padding="same", activation="relu"),
        layers.MaxPooling2D(),
        layers.Conv2D(32, 3, padding="same", activation="relu"),
        layers.MaxPooling2D(),
        layers.Conv2D(64, 3, padding="same", activation="relu"),
        layers.MaxPooling2D(),
        layers.Conv2D(64, 3, padding="same", activation="relu"),
        layers.MaxPooling2D(),
        layers.GlobalAveragePooling2D(),
        layers.Dropout(0.35),
        layers.Dense(num_classes, activation="softmax"),
    ])
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=1e-3),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def main():
    train_ds, val_ds, class_names = build_datasets()
    print("Classes:", class_names)

    model = build_model(len(class_names))
    model.summary()

    callbacks = [
        keras.callbacks.EarlyStopping(monitor="val_accuracy", patience=7, restore_best_weights=True),
    ]

    history = model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS, callbacks=callbacks)

    val_loss, val_acc = model.evaluate(val_ds)
    print(f"\nFinal validation accuracy: {val_acc:.4f}")
    print(f"Final validation loss: {val_loss:.4f}")

    model.save(MODELS_DIR / "tomato_disease_model.keras")

    metadata = {
        "class_names": class_names,
        "image_size": list(IMG_SIZE),
        "val_accuracy": float(val_acc),
        "val_loss": float(val_loss),
        "epochs_trained": len(history.history["loss"]),
    }
    with open(MODELS_DIR / "training_metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)
    print("Saved model and training_metadata.json to", MODELS_DIR)


if __name__ == "__main__":
    main()
