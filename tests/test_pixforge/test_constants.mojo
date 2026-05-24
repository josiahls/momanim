from std.testing import TestSuite, assert_equal
from momanim.constants import ColorSpace


def test_ColorSpace() raises:
    assert_equal(ColorSpace.YUV_420P, 2)
    assert_equal(ColorSpace.RGB_24, 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
