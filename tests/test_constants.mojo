from std.testing import TestSuite, assert_equal
from momanim.constants import ColorSpace


def test_ColorSpace() raises:
    assert_equal(ColorSpace.YUV_420P, 3)
    assert_equal(ColorSpace.RGB_24, 1)
    assert_equal(ColorSpace.RGBA_32, 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
