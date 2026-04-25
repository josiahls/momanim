from std.testing import TestSuite, assert_equal, assert_true

from momanim.rasterization.typing import *


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

    # What is c / d?
    # In decimal it is 0.66666667, and fixed point should be 43690


    # Lets experiment with pixel scenarios:
    # Given a image of 10x10
    # We have a location value of:
    var p0 = 5.5
    var p1 = 6.7

    var fp0 = FixedInt(p0)
    var fp1 = FixedInt(p1)
    # A single pixel in this scenario is 8 bpp so...
    var bpp_frac = FixedInt(8)
    var pixel_step_small = FixedInt(1) / bpp_frac
    var remainder = fp0 % bpp_frac
    var bpp_frac_small = bpp_frac.binary_div(2)

    # Given point 5.5 of total length 10. total pixels is 10 * 8 = 80
    # p0 should be somewhere between 4 and 5 of pixel coverage. Probably 4.
    print(fp0, fp1)

    #define N_X_FRAC(n)     ((n) == 1 ? 1 : (1 << ((n) / 2)) + 1)
    var n = 8
    var N_Y_FRAC = (1 << (n / 2)) - 1
    a = FixedInt(1)
    var STEP_Y_SMALL = a.value / N_Y_FRAC
    var STEP_Y_BIG = a.value - (N_Y_FRAC - 1) * STEP_Y_SMALL
    var Y_FRAC_FIRST = STEP_Y_BIG / 2
    var Y_FRAC_LAST = Y_FRAC_FIRST + (N_Y_FRAC - 1) * STEP_Y_SMALL
    print(N_Y_FRAC, STEP_Y_SMALL, STEP_Y_BIG, Y_FRAC_FIRST, Y_FRAC_LAST)

    var N_X_FRAC = (1 << (n / 2)) + 1
    var STEP_X_SMALL = a.value / N_X_FRAC
    var STEP_X_BIG = a.value - (N_X_FRAC - 1) * STEP_X_SMALL
    var X_FRAC_FIRST = STEP_X_BIG / 2
    var X_FRAC_LAST = X_FRAC_FIRST + (N_X_FRAC - 1) * STEP_X_SMALL
    print(N_X_FRAC, STEP_X_SMALL, STEP_X_BIG, X_FRAC_FIRST, X_FRAC_LAST)

    var RENDER_SAMPLES_X = (fp0.get_fractional_part().value + X_FRAC_FIRST) / STEP_X_SMALL
    print(RENDER_SAMPLES_X)

    # print(fp0, fp1, FixedInt(1),  FixedInt(8), pixel_step_small, bpp_frac, remainder, bpp_frac_small)


    # print(pixel_step_small.to_real_float(), bpp_frac.to_real_float(), remainder.to_real_float(), bpp_frac_small.to_real_float())    
    # var pixel_location = fp0 * bpp
    # print(pixel_location)
    # var pixel_overlap = fp0 % bpp
    # print(pixel_overlap)



def main() raises:
    # TestSuite.discover_tests[__functions_in_module()]().run()
    test_FixedPoint16()
