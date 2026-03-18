from momanim.data_structs.image import Image
from std.testing import TestSuite, assert_equal, assert_raises
from momanim.constants import ColorSpace


def test_image_init_validate() raises:
    var elements: List[UInt8] = [1, 2, 3, 4]
    with assert_raises(contains="must be a multiple"):
        var _ = Image(elements^)


def test_image_init_from_list() raises:
    var elements: List[UInt8] = [1, 2, 3, 4, 5, 6]
    var image = Image(elements^)
    assert_equal(image.w, 6)
    assert_equal(image.h, 1)
    assert_equal(image.ch, 1)
    assert_equal(image.color_space, ColorSpace.RGB_24)


def test_image_init_from_ptr() raises:
    var elements: List[UInt8] = [1, 2, 3, 4, 5, 6]
    var ptr = elements.unsafe_ptr().unsafe_origin_cast[MutExternalOrigin]()
    var image = Image(ptr, 6)
    assert_equal(image.w, 6)
    assert_equal(image.h, 1)
    assert_equal(image.ch, 1)
    assert_equal(image.color_space, ColorSpace.RGB_24)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
