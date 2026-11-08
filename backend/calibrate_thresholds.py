"""Measure blur and brightness scores on a folder of your own mango photos.

Use this to pick the blur and brightness thresholds in validation_config.py
from real data instead of guessing.

Usage (from the backend folder):
    python calibrate_thresholds.py path\\to\\photos
    python calibrate_thresholds.py path\\to\\photos --csv scores.csv

Tip: put photos you consider acceptable in one folder and photos you would
ask the user to retake (blurry, dark, glare) in another, run the script on
both, and choose thresholds that fall between the two groups.
"""

import argparse
import csv
from pathlib import Path

from image_validation import validate_image_bytes
from validation_config import load_config

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}
COLUMNS = [
    "file", "status", "width", "height", "blur_score", "global_laplacian_variance",
    "mean_brightness", "highlight_clipped", "shadow_clipped", "message",
]


def score_folder(folder: Path) -> list[dict]:
    config = load_config()
    rows = []
    for path in sorted(folder.rglob("*")):
        if path.suffix.lower() not in IMAGE_SUFFIXES:
            continue
        validated = validate_image_bytes(path.read_bytes(), config, filename=path.name)
        report = validated.report
        checks = {check.name: check for check in report.checks}
        blur = checks["blur"]
        brightness = checks["brightness"]
        rows.append({
            "file": str(path.relative_to(folder)),
            "status": report.status.value,
            "width": report.image.width,
            "height": report.image.height,
            "blur_score": blur.value,
            "global_laplacian_variance": blur.details.get("global_laplacian_variance"),
            "mean_brightness": brightness.value,
            "highlight_clipped": brightness.details.get("highlight_clipped_fraction"),
            "shadow_clipped": brightness.details.get("shadow_clipped_fraction"),
            "message": report.message,
        })
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("folder", type=Path)
    parser.add_argument("--csv", type=Path, help="Also save the scores to this CSV file.")
    args = parser.parse_args()

    rows = score_folder(args.folder)
    if not rows:
        print("No .jpg, .jpeg, .png or .webp files found.")
        return

    print(f"{'file':40} {'status':24} {'blur':>9} {'bright':>7}")
    for row in rows:
        print(f"{row['file'][:40]:40} {row['status']:24} "
              f"{row['blur_score']!s:>9} {row['mean_brightness']!s:>7}")

    blur_scores = sorted(r["blur_score"] for r in rows if isinstance(r["blur_score"], (int, float)))
    if blur_scores:
        print(f"\n{len(rows)} images. Blur score range {blur_scores[0]} to {blur_scores[-1]}, "
              f"median {blur_scores[len(blur_scores) // 2]}.")

    if args.csv:
        with args.csv.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=COLUMNS)
            writer.writeheader()
            writer.writerows(rows)
        print(f"Saved {args.csv}")


if __name__ == "__main__":
    main()
