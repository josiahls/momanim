from pathlib import Path

import cairo


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_PATH = (
    ROOT
    / "test_data"
    / "test_renderer"
    / "test_draw_vector_quarter_circle_segments_cairo.png"
)

WIDTH = 100
HEIGHT = 100
STROKE_WIDTH = 1.0
PIXEL_CENTER_OFFSET = 0.5

# Mirror the current active segment list in
# `test_draw_vector_quarter_circle_segments()` so Cairo output is directly
# comparable to the Mojo rasterizer output at the same resolution.
VECTORS = [
    ((35.0, 50.0), (35.0, 47.928932)),
    ((35.0, 47.928932), (35.41973, 45.9559)),
    ((35.41973, 45.9559), (36.17877, 44.161323)),
]


def main():
    surface = cairo.ImageSurface(cairo.Format.RGB24, WIDTH, HEIGHT)
    context = cairo.Context(surface)

    context.set_antialias(cairo.ANTIALIAS_DEFAULT)
    context.set_source_rgb(0.0, 0.0, 0.0)
    context.paint()

    context.set_source_rgb(1.0, 1.0, 1.0)
    context.set_line_width(STROKE_WIDTH)
    context.set_line_cap(cairo.LINE_CAP_BUTT)
    context.set_line_join(cairo.LINE_JOIN_MITER)

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


if __name__ == "__main__":
    main()
