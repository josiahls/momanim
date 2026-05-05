from std.testing import TestSuite, assert_equal, assert_not_equal, assert_true

# from momanim.rasterization.fixed_dtype  import (
#     FixedInt,
#     XPixelSampling,
#     YPixelSampling,
# )
# from momanim.rasterization.geometry_2d import Vector2d, Point2d, HalfPlane2d
from momanim.rasterization.fixed_dtype import (
    FixedDType, FixedPoint16x16, FixedPoint48x16, FixedInt
)


def test_FixedDType_unsigned() raises:
    """Test unsigned.
    
    Note, we don't have an actual unsigned
    dtype, however this is still important to test.
    """
    comptime UI32 = FixedDType[DType.uint32]

    assert_equal(UI32.max_value.value, 4294967296)
    assert_equal(UI32.min_value.value, 0)
    assert_equal(UInt32(4294967296), 4294967296)
    # Important: int32 converts 4294967296 to 0.
    assert_not_equal(Int64(4294967296), Int64(Int32(4294967296)))




def test_FixedPoint16x16() raises:
    # 16x16 should be a 50/50 portion for storing int and frac portions of the
    # value.
    assert_equal(FixedPoint16x16.int_bits, 16)
    assert_equal(FixedPoint16x16.frac_bits, 16)
    assert_equal(FixedPoint16x16.frac_scale, 65536.0)

    assert_equal(FixedPoint16x16.one.value, 65536)
    assert_equal(FixedPoint16x16.zero.value, 0)
    assert_equal(FixedPoint16x16.epsilon.value, 1)
    assert_equal(FixedPoint16x16.max_value.value, 2147483648)
    assert_equal(FixedPoint16x16.min_value.value, -2147483648)
    

def test_FixedPoint16x16__init__Int() raises:
    # Test integrals
    assert_equal(FixedPoint16x16(1).value, 65536)
    assert_equal(FixedPoint16x16(-1).value, -65536)
    assert_equal(FixedPoint16x16(0).value, 0)

def test_FixedPoint16x16__init__raw_value() raises:
    # Test raw integrals
    assert_equal(FixedPoint16x16(raw_value=1).value, 1)
    assert_equal(FixedPoint16x16(raw_value=-1).value, -1)
    assert_equal(FixedPoint16x16(raw_value=0).value, 0)


def test_FixedPoint16x16__init__Float32() raises:
    # Test floating point
    assert_equal(FixedPoint16x16(1.0).value, 65536)
    assert_equal(FixedPoint16x16(-1).value, -65536)
    assert_equal(FixedPoint16x16(0).value, 0)

    assert_equal(FixedPoint16x16(1.5).value, 98304)
    assert_equal(FixedPoint16x16(-1.5).value, -98304)

    # 0.00002 * 65536 = 1.31072 = 1
    # 0.00001 * 65536 = 0.65536 = 0
    assert_equal(FixedPoint16x16(0.00002).value, 1)
    assert_equal(FixedPoint16x16(-0.00002).value, -1)

    # 0.99999 * 65536 = 65535.34464 = 65535
    assert_equal(FixedPoint16x16(0.99999).value, 65535)
    assert_equal(FixedPoint16x16(-0.99999).value, -65535)



# def test_XPixelSampling() raises:
#     # Assuming we have an image that is 10 pixels wide.
#     # - Use FixedInt which is 16x16 using a uint32 container
#     # - The maximum value representable is 2^16 = 65536
#     # - The fixed point max value is 10 * 65536 = 655,360.
#     var x_pixel_coverage: Int = 0
#     var y_pixel_coverage: Int = 0
#     for i in range(100):
#         var x: Float32 = 5.0 + Float32(i / 100.0)
#         x_pixel_coverage = XPixelSampling.coverage(x)
#         y_pixel_coverage = YPixelSampling.coverage(x)
#         if i == 99:
#             assert_equal(x_pixel_coverage, 17)
#             assert_equal(y_pixel_coverage, 15)
#         elif i == 0:
#             assert_equal(x_pixel_coverage, 0)
#             assert_equal(y_pixel_coverage, 0)
#         elif i == 50:
#             assert_equal(x_pixel_coverage, 9)
#             assert_equal(y_pixel_coverage, 8)

#     var x_value = (
#         XPixelSampling.step_size * 5
#         + FixedInt.e
#         + XPixelSampling.first_step_size
#     )
#     # the sample loc should be 5
#     var x_sample_ceil = XPixelSampling.ceil(x_value)
#     var x_sample_floor = XPixelSampling.floor(x_value)
#     var ceil_step_size = (
#         XPixelSampling.step_size * 6 + XPixelSampling.first_step_size
#     )
#     var floor_step_size = (
#         XPixelSampling.step_size * 5 + XPixelSampling.first_step_size
#     )
#     print(
#         "x_value",
#         x_value,
#         "x_sample_ceil",
#         x_sample_ceil,
#         "x_sample_floor",
#         x_sample_floor,
#         "ceil_step_size",
#         ceil_step_size,
#         "floor_step_size",
#         floor_step_size,
#     )


# def test_FixedPoint16x16() raises:
#     # print("fixed point max value: ", FixedScalarUInt32.max_value)
#     var a = FixedInt(1)
#     assert_equal(Int(a), 65536)
#     assert_equal(a.to_real_int(), 1)
#     var b = FixedInt(2)
#     assert_equal(Int(b), 131072)
#     assert_equal(b.to_real_int(), 2)
#     var c = FixedInt(0.5)
#     assert_equal(Int(c), 32768)
#     assert_equal(c.to_real_float(), 0.5)
#     var d = FixedInt(0.75)
#     assert_equal(Int(d), 49152)
#     assert_equal(d.to_real_float(), 0.75)


# def test_FixedPointTrapezoid2d() raises:
#     # Test vector2d + thickness
#     var v = Vector2d(
#         p1=Point2d(0.0, 0.0),
#         p2=Point2d(1.0, 1.0),
#     )
#     var trapezoids = FixedPointTrapezoid2d.traps_from_edge(v, 0.5)
#     for trapezoid in trapezoids:
#         # TODO: check this is corret.
#         assert_equal(trapezoid.r.p0.x.to_real_float(), 0.17677307)
#         assert_equal(trapezoid.r.p0.y.to_real_float(), -0.17677307)
#         assert_equal(trapezoid.r.p1.x.to_real_float(), 0.82321167)
#         assert_equal(trapezoid.r.p1.y.to_real_float(), 1.1767731)

#         assert_equal(trapezoid.l.p0.x.to_real_float(), -0.17677307)
#         assert_equal(trapezoid.l.p0.y.to_real_float(), 0.17677307)
#         assert_equal(trapezoid.l.p1.x.to_real_float(), 1.1767731)
#         assert_equal(trapezoid.l.p1.y.to_real_float(), 0.82321167)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
    # test_FixedPoint16()
    # test_XPixelSampling()
    # test_FixedPointTrapezoid2d()
    # test_FixedPoint16x16()
