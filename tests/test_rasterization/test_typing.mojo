from std.testing import TestSuite, assert_equal, assert_true

from momanim.rasterization.typing import *




def test_XPixelSampling() raises:
    # Assuming we have an image that is 10 pixels wide.
    # - Use FixedInt which is 16x16 using a uint32 container
    # - The maximum value representable is 2^16 = 65536
    # - The fixed point max value is 10 * 65536 = 655,360.
    var x_pixel_coverage: Int = 0
    var y_pixel_coverage: Int = 0
    for i in range(100):
        var x:Float32 = 5.0 + Float32(i / 100.0)
        x_pixel_coverage = XPixelSampling.coverage(x)
        y_pixel_coverage = YPixelSampling.coverage(x)
        print(x_pixel_coverage, y_pixel_coverage, "->", (x_pixel_coverage * y_pixel_coverage))
        if i == 99:
            assert_equal(x_pixel_coverage, 17)
            assert_equal(y_pixel_coverage, 15)
        elif i == 0:
            assert_equal(x_pixel_coverage, 0)
            assert_equal(y_pixel_coverage, 0)
        elif i == 50:
            assert_equal(x_pixel_coverage, 9)
            assert_equal(y_pixel_coverage, 8)


def test_FixedPoint16() raises:
    # print("fixed point max value: ", FixedScalarUInt32.max_value)
    var a = FixedInt(1)
    assert_equal(Int(a), 65536)
    assert_equal(a.to_real_int(), 1)
    var b = FixedInt(2)
    assert_equal(Int(b), 131072)
    assert_equal(b.to_real_int(), 2)
    var c = FixedInt(0.5)
    assert_equal(Int(c), 32768)
    assert_equal(c.to_real_float(), 0.5)
    var d = FixedInt(0.75)
    assert_equal(Int(d), 49152)
    assert_equal(d.to_real_float(), 0.75)



def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
    # test_FixedPoint16()
    # test_XPixelSampling()
