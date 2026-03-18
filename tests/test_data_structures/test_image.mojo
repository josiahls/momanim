from momanim.data_structs.image import Image
from std.testing import TestSuite, assert_equal
from momanim.constants import ColorSpace


def test_image_init() raises:
    var elements: List[UInt8] = [1, 2, 3, 4]
    var image = Image(elements^)
    assert_equal(image.w, 4)
    assert_equal(image.h, 1)
    assert_equal(image.ch, 1)
    assert_equal(image.color_space, ColorSpace.RGB_24)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
