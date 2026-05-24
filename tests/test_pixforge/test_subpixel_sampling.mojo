from std.testing import (
    TestSuite, 
    assert_equal, 
    assert_not_equal, 
    assert_true, 
    assert_false
)
from std.math import floor

# from momanim.rasterization.geometry_2d import Vector2d, Point2d, HalfPlane2d
from momanim.rasterization.fixed_dtype import (
    FixedDType, FixedPoint16x16, FixedPoint48x16, FixedInt
)
from momanim.rasterization.subpixel_sampling import (
    PixelSampling,
    XPixelSampling,
    YPixelSampling,
)


def test_XPixelSampling_comptime() raises:
    assert_equal(XPixelSampling.samples_per_axis, 17)
    # Note: that the step size is truncated, thus the need for remainder
    assert_equal(XPixelSampling.step_size.value, 3855)
    # The remainder, the remaining step, is +1 more than the regualr step sizes.
    assert_equal(XPixelSampling.step_remainder.value, 3856)
    assert_equal(XPixelSampling.step_span.value, 61680)
    assert_equal(XPixelSampling.first_step_size.value, 1928)
    assert_equal(XPixelSampling.last_step_start.value, 61680 + 1928)


def test_XPixelSampling_ceil() raises:
    # 1927 is just -1 less than the first_step_size location. ceil will 
    # bump it to 1927.
    assert_equal(
        XPixelSampling.ceil(FixedInt(raw_value=1927)).value, 
        XPixelSampling.first_step_size.value
    ) 
    assert_equal(
        XPixelSampling.ceil(FixedInt(raw_value=1928)).value, 
        XPixelSampling.first_step_size.value
    ) 
    # ceil should round 1929 to the end of the next step.
    assert_equal(
        XPixelSampling.ceil(FixedInt(raw_value=1929)).value, 
        XPixelSampling.first_step_size.value + XPixelSampling.step_size.value
    ) 

    # 65536 should be +1 the last step end. Should wrap around to the first step.
    assert_equal(
        XPixelSampling.ceil(FixedInt(raw_value=65536)).value, 
        # Wraps around to: 65536 (entire pixel) + first_step_size (the next pixel)
        67464
    ) 

def test_XPixelSampling_floor() raises:
    # 1927 is just -1 less than the first_step_size location. ceil will 
    # bump it to 1927.
    assert_equal(
        XPixelSampling.floor(FixedInt(raw_value=1927)).value, 
        -1928
    ) 
    assert_equal(
        XPixelSampling.floor(FixedInt(raw_value=1928)).value, 
        -1928
    ) 
    # ceil should round 1929 to the end of the next step.
    assert_equal(
        XPixelSampling.floor(FixedInt(raw_value=1929)).value, 
        XPixelSampling.first_step_size.value
    ) 

    # 65536 should be +1 the last step end. Should wrap backward to the last step start.
    assert_equal(
        XPixelSampling.floor(FixedInt(raw_value=65536)).value, 
        # Wraps back to the previous pixel + the last step start.
        61680 + 1928
    ) 




def test_XPixelSampling() raises:
    # Assuming we have an image that is 10 pixels wide.
    # - Use FixedInt which is 16x16 using a uint32 container
    # - The maximum value representable is 2^16 = 65536
    # - The fixed point max value is 10 * 65536 = 655,360.
    var x_pixel_coverage: Int = 0
    var y_pixel_coverage: Int = 0
    for i in range(100):
        var x: Float32 = 5.0 + Float32(i / 100.0)
        x_pixel_coverage = XPixelSampling.coverage(x)
        y_pixel_coverage = YPixelSampling.coverage(x)
        if i == 99:
            assert_equal(x_pixel_coverage, 17)
            assert_equal(y_pixel_coverage, 15)
        elif i == 0:
            assert_equal(x_pixel_coverage, 0)
            assert_equal(y_pixel_coverage, 0)
        elif i == 50:
            assert_equal(x_pixel_coverage, 9)
            assert_equal(y_pixel_coverage, 8)

    var x_value = (
        XPixelSampling.step_size * 5
        + FixedInt.epsilon
        + XPixelSampling.first_step_size
    )
    # # the sample loc should be 5
    # var x_sample_ceil = XPixelSampling.ceil(x_value)
    # var x_sample_floor = XPixelSampling.floor(x_value)
    # var ceil_step_size = (
    #     XPixelSampling.step_size * 6 + XPixelSampling.first_step_size
    # )
    # var floor_step_size = (
    #     XPixelSampling.step_size * 5 + XPixelSampling.first_step_size
    # )



def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()