bnfrom std.testing import (
    TestSuite, 
    assert_equal, 
    assert_not_equal, 
    assert_true, 
    assert_false
)
from std.math import floor
from momanim.rasterization.image import *


def test_ColorImage_init() raises:
    var image = ColorImage(fill=RGBA(255,0,0,255), width=100, height=100)
    assert_equal(image.line_size, 112)
    assert_equal(image.size, 112 * 100)
    assert_equal(image.buffer[0], [255, 0, 0, 255])
    assert_equal(image.buffer[112 * 100 - 1], [255, 0, 0, 255])


def test_MaskImage_init() raises:
    var image = MaskImage(fill=255, width=100, height=100)
    assert_equal(image.line_size, 112)
    assert_equal(image.buffer[0], 255)
    assert_equal(image.buffer[112 * 100 - 1], 255)
    # assert_equal(image.buffer, [255, 0, 0, 255])


def test_SolidImage_init() raises:
    var image = SolidImage(rgba=RGBA(255,0,0,255))
    assert_equal(image.buffer, [255, 0, 0, 255])



def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
