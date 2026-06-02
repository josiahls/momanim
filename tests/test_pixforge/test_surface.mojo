from std.testing import (
    TestSuite, 
    assert_equal, 
    assert_not_equal, 
    assert_true, 
    assert_false
)
from std.math import floor
from momanim.pix_forge.surface import *


def test_ColorSurface_init() raises:
    var surface = ColorSurface(fill=RGBA(1,0,0,1), width=100, height=100)
    assert_equal(surface.line_size, 112)
    assert_equal(surface.size, 112 * 100)
    assert_equal(surface.buffer[0], [1, 0, 0, 1])
    assert_equal(surface.buffer[112 * 100 - 1], [1, 0, 0, 1])


def test_MaskSurface_init() raises:
    var surface = MaskSurface(fill=255, width=100, height=100)
    assert_equal(surface.line_size, 112)
    assert_equal(surface.buffer[0], 255)
    assert_equal(surface.buffer[112 * 100 - 1], 255)
    # assert_equal(image.buffer, [255, 0, 0, 255])


def test_SolidSurface_init() raises:
    var surface = SolidSurface(rgba=RGBA(1,0,0,1))
    assert_equal(surface.buffer, [1, 0, 0, 1])



def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
