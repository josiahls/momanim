from std.testing import (
    TestSuite, 
    assert_equal, 
    assert_not_equal, 
    assert_true, 
    assert_false
)
from std.os import getenv
from std.math import floor
from momanim.pix_forge.color import *
from momanim.pix_forge.surface import *
from momanim.pix_forge.paint import paint
from momanim.pix_forge.testing import test_surface_to_png


comptime painted_to_png = test_surface_to_png["test_pixforge/test_paint", _]


def test_ColorSurface_paint() raises:
    var target = ColorSurface(fill=RGBA_F(1,0,0,1), width=100, height=100)
    var pattern = SolidSurface(rgba=RGBA_F(0,0,1,1))

    paint(target, pattern)

    painted_to_png["test_ColorSurface_paint"](target)
    # var test_data_root = getenv("PIXI_PROJECT_ROOT")



# def test_MaskSurface_init() raises:
#     var surface = MaskSurface(fill=255, width=100, height=100)
#     assert_equal(surface.line_size, 112)
#     assert_equal(surface.buffer[0], 255)
#     assert_equal(surface.buffer[112 * 100 - 1], 255)
#     # assert_equal(image.buffer, [255, 0, 0, 255])


# def test_SolidSurface_init() raises:
#     var surface = SolidSurface(rgba=RGBA(255,0,0,255))
#     assert_equal(surface.buffer, [255, 0, 0, 255])



def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
