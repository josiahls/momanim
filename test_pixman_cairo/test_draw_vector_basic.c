/*
 * Cairo reference for tests/test_rasterization/test_rasterize.mojo
 * test_draw_vector_basic: line (0, 0) -> (99, 9), thickness 1.
 */
#include <cairo.h>
#include <stdio.h>

#define W 10
#define H 10

int
main(void)
{
    cairo_surface_t *surface;
    cairo_t *cr;
    cairo_status_t status;
    const char *out_path =
        "test_data/test_rasterize/test_draw_vector_basic_cairo.png";

    surface = cairo_image_surface_create(CAIRO_FORMAT_A8, W, H);
    if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
        fprintf(stderr, "cairo_image_surface_create failed\n");
        return 1;
    }

    cr = cairo_create(surface);
    if (cairo_status(cr) != CAIRO_STATUS_SUCCESS) {
        fprintf(stderr, "cairo_create failed\n");
        cairo_surface_destroy(surface);
        return 1;
    }

    cairo_set_antialias(cr, CAIRO_ANTIALIAS_GRAY);
    cairo_set_line_width(cr, 1.0);
    // cairo_set_line_cap(cr, CAIRO_LINE_CAP_SQUARE);
    // cairo_set_line_join(cr, CAIRO_LINE_JOIN_MITER);
    cairo_set_source_rgba(cr, 0, 0, 0, 1);
    cairo_move_to(cr, 0.0, 0.0);
    cairo_line_to(cr, 9.0, 9.0);
    cairo_stroke(cr);

    if (cairo_status(cr) != CAIRO_STATUS_SUCCESS) {
        fprintf(stderr, "cairo_stroke failed\n");
        cairo_destroy(cr);
        cairo_surface_destroy(surface);
        return 1;
    }

    cairo_destroy(cr);

    status = cairo_surface_write_to_png(surface, out_path);
    if (status != CAIRO_STATUS_SUCCESS) {
        fprintf(stderr, "cairo_surface_write_to_png failed: %s\n",
            cairo_status_to_string(status));
        cairo_surface_destroy(surface);
        return 1;
    }

    cairo_surface_destroy(surface);
    printf("wrote %s\n", out_path);
    return 0;
}
