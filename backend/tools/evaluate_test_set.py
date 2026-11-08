"""Run the backend's ModelService on the stored test set and print the results.

Use it to confirm that the integrated backend gives the same results as the
verification in Colab (LiteRT 2.3.0, stored test images):
    all 281 images:      accuracy 0.7544
    Guimaras 217 images: accuracy 0.7696

The stored test images are already the 224x224 JPEG q95 files the model was
evaluated on, so they are decoded and fed directly (no second JPEG step).

Usage (from the backend folder, in .venv313):
    python tools/evaluate_test_set.py "C:\\path\\to\\MangGrade_Dataset_Ready\\test"

The folder must contain one sub-folder per class:
    Extra_Class, Class_I, Class_II, Reject
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from model_service import GRADES, ModelService  # noqa: E402

FOLDERS = ["Extra_Class", "Class_I", "Class_II", "Reject"]  # same order as GRADES
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png"}


def main(test_dir: Path) -> int:
    service = ModelService()
    if not service.load():
        print("Model not loaded:", service.error)
        return 1
    print("Model:", service.status()["model"]["sha256"], service.status()["model"]["runtime"])

    rows = []  # (true index, predicted index, is_online)
    for true_index, folder in enumerate(FOLDERS):
        directory = test_dir / folder
        if not directory.is_dir():
            print("Missing folder:", directory)
            return 1
        for path in sorted(directory.iterdir()):
            if path.suffix.lower() not in IMAGE_SUFFIXES:
                continue
            with Image.open(path) as image:
                array = np.asarray(image.convert("RGB"), dtype=np.float32)
            if array.shape != (224, 224, 3):
                print("Not a 224x224 stored test image:", path)
                return 1
            prediction = service.predict(array)
            rows.append((true_index, prediction.index, "_online_" in path.name.lower()))

    for title, subset in (("All", rows), ("Guimaras", [r for r in rows if not r[2]])):
        matrix = np.zeros((len(GRADES), len(GRADES)), dtype=int)
        for true_index, predicted_index, _ in subset:
            matrix[true_index, predicted_index] += 1
        correct = int(np.trace(matrix))
        print(f"\n{title}: {correct}/{len(subset)} correct, accuracy {correct / len(subset):.4f}")
        print("rows = true, columns = predicted:", ", ".join(GRADES))
        for grade, row in zip(GRADES, matrix):
            print(f"  {grade:<12}", " ".join(f"{v:4d}" for v in row))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(Path(sys.argv[1])))
