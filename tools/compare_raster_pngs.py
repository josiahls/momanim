#!/usr/bin/env python3
"""Compare two grayscale raster PNGs under test_data/test_rasterize/."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

RASTER_DIR = Path("test_data/test_rasterize")


def load_gray(path: Path) -> Image.Image:
    if not path.is_file():
        raise FileNotFoundError(path)
    return Image.open(path).convert("L")


def compare(left: Image.Image, right: Image.Image, left_name: str, right_name: str) -> int:
    if left.size != right.size:
        print(
            f"size mismatch: {left_name} {left.size} vs {right_name} {right.size}",
            file=sys.stderr,
        )
        return 2

    width, height = left.size
    left_data = list(left.get_flattened_data())
    right_data = list(right.get_flattened_data())
    diffs: list[tuple[int, int, int, int, int]] = []

    for y in range(height):
        for x in range(width):
            idx = y * width + x
            lv = left_data[idx]
            rv = right_data[idx]
            if lv != rv:
                diffs.append((x, y, lv, rv, rv - lv))

    print(f"{left_name}: max={max(left_data)} nonzero={sum(1 for v in left_data if v)}")
    print(f"{right_name}: max={max(right_data)} nonzero={sum(1 for v in right_data if v)}")
    print(f"diff pixels: {len(diffs)} / {width * height}")

    if not diffs:
        print("images match exactly")
        return 0

    max_abs = max(abs(d[4]) for d in diffs)
    mean_abs = sum(abs(d[4]) for d in diffs) / len(diffs)
    print(f"max |diff|: {max_abs}")
    print(f"mean |diff|: {mean_abs:.2f}")
    print()
    print(f"x y {left_name} {right_name} diff")
    for x, y, lv, rv, delta in sorted(diffs, key=lambda item: (-abs(item[4]), item[1], item[0])):
        print(f"{x} {y} {lv:3d} {rv:3d} {delta:+4d}")

    return 1


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Diff two grayscale PNGs in test_data/test_rasterize/."
    )
    parser.add_argument("left", help="First PNG filename (e.g. test_draw_vector_basic.png)")
    parser.add_argument("right", help="Second PNG filename (e.g. test_draw_vector_basic_cairo.png)")
    args = parser.parse_args()

    left_path = RASTER_DIR / args.left
    right_path = RASTER_DIR / args.right

    try:
        left = load_gray(left_path)
        right = load_gray(right_path)
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        return 2

    return compare(left, right, args.left, args.right)


if __name__ == "__main__":
    raise SystemExit(main())
