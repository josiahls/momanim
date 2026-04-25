from pathlib import Path

import cairo
from time import time


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_PATH = ROOT / "test_data" / "test_renderer" / "test_draw_vector_cairo.png"


WIDTH = 50
HEIGHT = 50
STROKE_WIDTH = 0.75
PIXEL_CENTER_OFFSET = 0.5

# Mirror the current Mojo test as-written so the rendered reference stays
# comparable to the checked-in PNG, including the duplicated v3 draw and the
# missing v4 draw.
VECTORS = [
        ((25.0, 25.0), (37.0, 49.0)),
        ((25.0, 25.0), (49.0, 37.0)),
        ((25.0, 24.0), (37.0, 0.0)),
        ((25.0, 24.0), (49.0, 12.0)),
        ((24.0, 24.0), (12.0, 0.0)),
        ((24.0, 24.0), (0.0, 12.0)),
        ((24.0, 25.0), (0.0, 37.0)),
        ((24.0, 25.0), (12.0, 49.0)),
]


def main():
    start_time = time()
    surface = cairo.ImageSurface(cairo.Format.RGB24, WIDTH, HEIGHT)
    context = cairo.Context(surface)

    context.set_antialias(cairo.ANTIALIAS_DEFAULT)
    context.set_source_rgb(0.0, 0.0, 0.0)
    context.paint()

    context.set_source_rgb(1.0, 1.0, 1.0)
    context.set_line_width(STROKE_WIDTH)
    context.set_line_cap(cairo.LINE_CAP_BUTT)

    for start_px, end_px in VECTORS:
        context.move_to(
            start_px[0] + PIXEL_CENTER_OFFSET,
            start_px[1] + PIXEL_CENTER_OFFSET,
        )
        context.line_to(
            end_px[0] + PIXEL_CENTER_OFFSET,
            end_px[1] + PIXEL_CENTER_OFFSET,
        )
        context.stroke()

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    surface.write_to_png(str(OUTPUT_PATH))
    print(f"Wrote {OUTPUT_PATH}")
    end_time = time()
    print(f"Time taken: {end_time - start_time} seconds")


if __name__ == "__main__":
    main()
