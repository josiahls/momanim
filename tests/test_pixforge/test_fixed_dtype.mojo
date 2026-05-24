from std.testing import (
    TestSuite, 
    assert_equal, 
    assert_not_equal, 
    assert_true, 
    assert_false
)
from std.math import floor

from momanim.rasterization.fixed_dtype import (
    FixedDType, FixedPoint16x16, FixedPoint48x16, FixedInt
)


def test_FixedDType_uint32_unsigned() raises:
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
    assert_equal(FixedPoint16x16.max_int_value.value, 32768)
    assert_equal(FixedPoint16x16.min_int_value.value, -32768)

def test_FixedPoint16x16__init__Int() raises:
    # Test integrals
    assert_equal(FixedPoint16x16(from_int=1).value, 65536)
    assert_equal(FixedPoint16x16(from_int=-1).value, -65536)
    assert_equal(FixedPoint16x16(from_int=0).value, 0)

def test_FixedPoint16x16__init__raw_value() raises:
    # Test raw integrals
    assert_equal(FixedPoint16x16(raw_value=1).value, 1)
    assert_equal(FixedPoint16x16(raw_value=-1).value, -1)
    assert_equal(FixedPoint16x16(raw_value=0).value, 0)

def test_FixedPoint16x16__init__Float32() raises:
    # Test floating point
    assert_equal(FixedPoint16x16(from_float=1.0).value, 65536)
    assert_equal(FixedPoint16x16(from_float=-1).value, -65536)
    assert_equal(FixedPoint16x16(from_float=0).value, 0)

    assert_equal(FixedPoint16x16(from_float=1.5).value, 98304)
    assert_equal(FixedPoint16x16(from_float=-1.5).value, -98304)

    # 0.00002 * 65536 = 1.31072 = 1
    # 0.00001 * 65536 = 0.65536 = 0
    assert_equal(FixedPoint16x16(from_float=0.00002).value, 1)
    assert_equal(FixedPoint16x16(from_float=-0.00002).value, -1)

    # 0.99999 * 65536 = 65535.34464 = 65535
    assert_equal(FixedPoint16x16(from_float=0.99999).value, 65535)
    assert_equal(FixedPoint16x16(from_float=-0.99999).value, -65535)

def test_FixedPoint16x16__eq__() raises:
    assert_true(FixedPoint16x16(from_int=1) == FixedPoint16x16(from_int=1))
    assert_false(FixedPoint16x16(from_int=1) == FixedPoint16x16(from_int=2))

def test_FixedPoint16x16__lt__() raises:
    assert_true(FixedPoint16x16(from_int=1) < FixedPoint16x16(from_int=2))
    assert_false(FixedPoint16x16(from_int=2) < FixedPoint16x16(from_int=1))

def test_FixedPoint16x16__sub__() raises:
    assert_equal(FixedPoint16x16(from_int=1) - FixedPoint16x16(from_int=2), FixedPoint16x16(from_int=-1))
    assert_equal(FixedPoint16x16(from_int=2) - FixedPoint16x16(from_int=1), FixedPoint16x16(from_int=1))

def test_FixedPoint16x16__add__() raises:
    assert_equal(FixedPoint16x16(from_int=1) + FixedPoint16x16(from_int=2), FixedPoint16x16(from_int=3))
    assert_equal(FixedPoint16x16(from_int=2) + FixedPoint16x16(from_int=1), FixedPoint16x16(from_int=3))

def test_FixedPoint16x16_fixed_mul() raises:
    assert_equal(FixedPoint16x16(from_int=1).fixed_mul[DType.int64](FixedPoint16x16(from_int=2)), FixedPoint16x16(from_int=2))
    assert_equal(FixedPoint16x16(from_int=2).fixed_mul[DType.int64](FixedPoint16x16(from_int=1)), FixedPoint16x16(from_int=2))
    assert_equal(FixedPoint16x16(from_int=-1).fixed_mul[DType.int64](FixedPoint16x16(from_int=2)), FixedPoint16x16(from_int=-2))
    assert_equal(FixedPoint16x16(from_int=-2).fixed_mul[DType.int64](FixedPoint16x16(from_int=1)), FixedPoint16x16(from_int=-2))

def test_FixedPoint16x16_fixed_div() raises:
    assert_equal(FixedPoint16x16(from_int=1).fixed_div[DType.int64](FixedPoint16x16(from_int=2)), FixedPoint16x16(from_float=0.5))
    assert_equal(FixedPoint16x16(from_int=2).fixed_div[DType.int64](FixedPoint16x16(from_int=1)), FixedPoint16x16(from_int=2))
    assert_equal(FixedPoint16x16(from_int=-1).fixed_div[DType.int64](FixedPoint16x16(from_int=2)), FixedPoint16x16(from_float=-0.5))
    assert_equal(FixedPoint16x16(from_int=-1).fixed_div[DType.int64](FixedPoint16x16(from_int=-2)), FixedPoint16x16(from_float=0.5))

def test_FixedPoint16x16_floor_div() raises:
    assert_equal(FixedPoint16x16(from_int=1).floor_div(FixedPoint16x16(from_int=2)), FixedPoint16x16(from_int=0))
    assert_equal(FixedPoint16x16(from_int=2).floor_div(FixedPoint16x16(from_int=1)), FixedPoint16x16(from_int=2))
    assert_equal(FixedPoint16x16(from_int=-1).floor_div(FixedPoint16x16(from_int=2)), FixedPoint16x16(from_int=0))
    assert_equal(FixedPoint16x16(from_int=-1).floor_div(FixedPoint16x16(from_int=-2)), FixedPoint16x16(from_int=0))

def test_FixedPoint16x16_negative_floor_div() raises:
    assert_equal(FixedPoint16x16(from_int=1).negative_floor_div(FixedPoint16x16(from_int=2)), FixedPoint16x16(from_int=0))
    assert_equal(FixedPoint16x16(from_int=2).negative_floor_div(FixedPoint16x16(from_int=1)), FixedPoint16x16(from_int=2))
    assert_equal(FixedPoint16x16(from_int=-1).negative_floor_div(FixedPoint16x16(from_int=2)), FixedPoint16x16(from_int=-1))
    assert_equal(FixedPoint16x16(from_int=-1).negative_floor_div(FixedPoint16x16(from_int=-2)), FixedPoint16x16(from_int=0))

def test_FixedPoint16x16__mod__() raises:
    assert_equal(FixedPoint16x16(from_int=1) % FixedPoint16x16(from_int=2), FixedPoint16x16(from_int=1))
    assert_equal(FixedPoint16x16(from_int=2) % FixedPoint16x16(from_int=1), FixedPoint16x16(from_int=0))

def test_FixedPoint16x16__and__() raises:
    assert_equal(FixedPoint16x16(from_int=1) & FixedPoint16x16(from_int=2), FixedPoint16x16(from_int=0))
    assert_equal(FixedPoint16x16(from_int=2) & FixedPoint16x16(from_int=1), FixedPoint16x16(from_int=0))

def test_FixedPoint16x16__int__() raises:
    assert_equal(Int(FixedPoint16x16(from_int=1)), 1)
    assert_equal(Int(FixedPoint16x16(from_int=2)), 2)

def test_FixedPoint16x16__float__() raises:
    assert_equal(Float64(FixedPoint16x16(from_int=1)), 1.0)
    assert_equal(Float64(FixedPoint16x16(from_int=2)), 2.0)
    assert_equal(Float64(FixedPoint16x16(from_float=1.5)), 1.5)

def test_FixedPoint16x16__frac__() raises:
    assert_equal(FixedPoint16x16(from_int=1).frac(), FixedPoint16x16(from_int=0))
    assert_equal(FixedPoint16x16(from_int=2).frac(), FixedPoint16x16(from_int=0))
    assert_equal(FixedPoint16x16(from_float=1.5).frac(), FixedPoint16x16(from_float=0.5))
    assert_equal(FixedPoint16x16(from_float=2.5).frac(), FixedPoint16x16(from_float=0.5))

def test_FixedPoint16x16__neg__() raises:
    assert_equal(-FixedPoint16x16(from_int=1), FixedPoint16x16(from_int=-1))
    assert_equal(-FixedPoint16x16(from_int=2), FixedPoint16x16(from_int=-2))

def test_FixedPoint16x16__iadd__() raises:
    var a = FixedPoint16x16(from_int=1)
    a += FixedPoint16x16(from_int=2)
    assert_equal(a, FixedPoint16x16(from_int=3))
    var b = FixedPoint16x16(from_int=2)
    b += FixedPoint16x16(from_int=1)
    assert_equal(b, FixedPoint16x16(from_int=3))

def test_FixedPoint16x16__isub__() raises:
    var a = FixedPoint16x16(from_int=1)
    a -= FixedPoint16x16(from_int=2)
    assert_equal(a, FixedPoint16x16(from_int=-1))
    var b = FixedPoint16x16(from_int=2)
    b -= FixedPoint16x16(from_int=1)
    assert_equal(b, FixedPoint16x16(from_int=1))

def test_FixedPoint16x16__floor__() raises:
    assert_equal(floor(FixedPoint16x16(from_int=1)), FixedPoint16x16(from_int=1))
    assert_equal(floor(FixedPoint16x16(from_int=2)), FixedPoint16x16(from_int=2))
    assert_equal(floor(FixedPoint16x16(from_float=1.5)), FixedPoint16x16(from_int=1))
    assert_equal(floor(FixedPoint16x16(from_float=2.5)), FixedPoint16x16(from_int=2))

def test_FixedPoint16x16__or__() raises:
    assert_equal(FixedPoint16x16(from_int=1) | FixedPoint16x16(from_int=2), FixedPoint16x16(from_int=3))
    assert_equal(FixedPoint16x16(from_int=2) | FixedPoint16x16(from_int=1), FixedPoint16x16(from_int=3))

def test_FixedPoint48x16() raises:
    # 16x16 should be a 50/50 portion for storing int and frac portions of the
    # value.
    assert_equal(FixedPoint48x16.int_bits, 48)
    assert_equal(FixedPoint48x16.frac_bits, 16)
    assert_equal(FixedPoint48x16.frac_scale, 65536.0)

    assert_equal(FixedPoint48x16.one.value, 65536)
    assert_equal(FixedPoint48x16.zero.value, 0)
    assert_equal(FixedPoint48x16.epsilon.value, 1)
    assert_equal(FixedPoint48x16.max_value.value, 9223372036854775808)
    assert_equal(FixedPoint48x16.min_value.value, -9223372036854775808)

def test_FixedPoint48x16__init__Int() raises:
    # Test integrals
    assert_equal(FixedPoint48x16(from_int=1).value, 65536)
    assert_equal(FixedPoint48x16(from_int=-1).value, -65536)
    assert_equal(FixedPoint48x16(from_int=0).value, 0)

def test_FixedPoint48x16__init__raw_value() raises:
    # Test raw integrals
    assert_equal(FixedPoint48x16(raw_value=1).value, 1)
    assert_equal(FixedPoint48x16(raw_value=-1).value, -1)
    assert_equal(FixedPoint48x16(raw_value=0).value, 0)

def test_FixedPoint48x16__init__Float32() raises:
    # Test floating point
    assert_equal(FixedPoint48x16(from_float=1.0).value, 65536)
    assert_equal(FixedPoint48x16(from_float=-1).value, -65536)
    assert_equal(FixedPoint48x16(from_float=0).value, 0)

    assert_equal(FixedPoint48x16(from_float=1.5).value, 98304)
    assert_equal(FixedPoint48x16(from_float=-1.5).value, -98304)

    # 0.00002 * 65536 = 1.31072 = 1
    # 0.00001 * 65536 = 0.65536 = 0
    assert_equal(FixedPoint48x16(from_float=0.00002).value, 1)
    assert_equal(FixedPoint48x16(from_float=-0.00002).value, -1)

    # 0.99999 * 65536 = 65535.34464 = 65535
    assert_equal(FixedPoint48x16(from_float=0.99999).value, 65535)
    assert_equal(FixedPoint48x16(from_float=-0.99999).value, -65535)

def test_FixedPoint48x16__eq__() raises:
    assert_true(FixedPoint48x16(from_int=1) == FixedPoint48x16(from_int=1))
    assert_false(FixedPoint48x16(from_int=1) == FixedPoint48x16(from_int=2))

def test_FixedPoint48x16__lt__() raises:
    assert_true(FixedPoint48x16(from_int=1) < FixedPoint48x16(from_int=2))
    assert_false(FixedPoint48x16(from_int=2) < FixedPoint48x16(from_int=1))

def test_FixedPoint48x16__sub__() raises:
    assert_equal(FixedPoint48x16(from_int=1) - FixedPoint48x16(from_int=2), FixedPoint48x16(from_int=-1))
    assert_equal(FixedPoint48x16(from_int=2) - FixedPoint48x16(from_int=1), FixedPoint48x16(from_int=1))

def test_FixedPoint48x16__add__() raises:
    assert_equal(FixedPoint48x16(from_int=1) + FixedPoint48x16(from_int=2), FixedPoint48x16(from_int=3))
    assert_equal(FixedPoint48x16(from_int=2) + FixedPoint48x16(from_int=1), FixedPoint48x16(from_int=3))

def test_FixedPoint48x16_fixed_mul() raises:
    assert_equal(FixedPoint48x16(from_int=1).fixed_mul[DType.int128](FixedPoint48x16(from_int=2)), FixedPoint48x16(from_int=2))
    assert_equal(FixedPoint48x16(from_int=2).fixed_mul[DType.int128](FixedPoint48x16(from_int=1)), FixedPoint48x16(from_int=2))

def test_FixedPoint48x16_fixed_div() raises:
    assert_equal(FixedPoint48x16(from_int=1).fixed_div[DType.int128](FixedPoint48x16(from_int=2)), FixedPoint48x16(from_float=0.5))
    assert_equal(FixedPoint48x16(from_int=2).fixed_div[DType.int128](FixedPoint48x16(from_int=1)), FixedPoint48x16(from_int=2))
    assert_equal(FixedPoint48x16(from_int=-1).fixed_div[DType.int128](FixedPoint48x16(from_int=2)), FixedPoint48x16(from_float=-0.5))
    assert_equal(FixedPoint48x16(from_int=-1).fixed_div[DType.int128](FixedPoint48x16(from_int=-2)), FixedPoint48x16(from_float=0.5))

def test_FixedPoint48x16_floor_div() raises:
    assert_equal(FixedPoint48x16(from_int=1).floor_div(FixedPoint48x16(from_int=2)), FixedPoint48x16(from_int=0))
    assert_equal(FixedPoint48x16(from_int=2).floor_div(FixedPoint48x16(from_int=1)), FixedPoint48x16(from_int=2))
    assert_equal(FixedPoint48x16(from_int=-1).floor_div(FixedPoint48x16(from_int=2)), FixedPoint48x16(from_int=0))
    assert_equal(FixedPoint48x16(from_int=-1).floor_div(FixedPoint48x16(from_int=-2)), FixedPoint48x16(from_int=0))

def test_FixedPoint48x16_negative_floor_div() raises:
    assert_equal(FixedPoint48x16(from_int=1).negative_floor_div(FixedPoint48x16(from_int=2)), FixedPoint48x16(from_int=0))
    assert_equal(FixedPoint48x16(from_int=2).negative_floor_div(FixedPoint48x16(from_int=1)), FixedPoint48x16(from_int=2))
    assert_equal(FixedPoint48x16(from_int=-1).negative_floor_div(FixedPoint48x16(from_int=2)), FixedPoint48x16(from_int=-1))
    assert_equal(FixedPoint48x16(from_int=-1).negative_floor_div(FixedPoint48x16(from_int=-2)), FixedPoint48x16(from_int=0))

def test_FixedPoint48x16__mod__() raises:
    assert_equal(FixedPoint48x16(from_int=1) % FixedPoint48x16(from_int=2), FixedPoint48x16(from_int=1))
    assert_equal(FixedPoint48x16(from_int=2) % FixedPoint48x16(from_int=1), FixedPoint48x16(from_int=0))

def test_FixedPoint48x16__and__() raises:
    assert_equal(FixedPoint48x16(from_int=1) & FixedPoint48x16(from_int=2), FixedPoint48x16(from_int=0))
    assert_equal(FixedPoint48x16(from_int=2) & FixedPoint48x16(from_int=1), FixedPoint48x16(from_int=0))

def test_FixedPoint48x16__int__() raises:
    assert_equal(Int(FixedPoint48x16(from_int=1)), 1)
    assert_equal(Int(FixedPoint48x16(from_int=2)), 2)

def test_FixedPoint48x16__float__() raises:
    assert_equal(Float64(FixedPoint48x16(from_int=1)), 1.0)
    assert_equal(Float64(FixedPoint48x16(from_int=2)), 2.0)
    assert_equal(Float64(FixedPoint48x16(from_float=1.5)), 1.5)

def test_FixedPoint48x16__frac__() raises:
    assert_equal(FixedPoint48x16(from_float=1).frac(), FixedPoint48x16(from_float=0))
    assert_equal(FixedPoint48x16(from_float=2).frac(), FixedPoint48x16(from_float=0))
    assert_equal(FixedPoint48x16(from_float=1.5).frac(), FixedPoint48x16(from_float=0.5))
    assert_equal(FixedPoint48x16(from_float=2.5).frac(), FixedPoint48x16(from_float=0.5))

def test_FixedPoint48x16__neg__() raises:
    assert_equal(-FixedPoint48x16(from_int=1), FixedPoint48x16(from_int=-1))
    assert_equal(-FixedPoint48x16(from_int=2), FixedPoint48x16(from_int=-2))

def test_FixedPoint48x16__iadd__() raises:
    var a = FixedPoint48x16(from_int=1)
    a += FixedPoint48x16(from_int=2)
    assert_equal(a, FixedPoint48x16(from_int=3))
    var b = FixedPoint48x16(from_int=2)
    b += FixedPoint48x16(from_int=1)
    assert_equal(b, FixedPoint48x16(from_int=3))

def test_FixedPoint48x16__isub__() raises:
    var a = FixedPoint48x16(from_int=1)
    a -= FixedPoint48x16(from_int=2)
    assert_equal(a, FixedPoint48x16(from_int=-1))
    var b = FixedPoint48x16(from_int=2)
    b -= FixedPoint48x16(from_int=1)
    assert_equal(b, FixedPoint48x16(from_int=1))

def test_FixedPoint48x16__floor__() raises:
    assert_equal(floor(FixedPoint48x16(from_float=1)), FixedPoint48x16(from_float=1))
    assert_equal(floor(FixedPoint48x16(from_float=2)), FixedPoint48x16(from_float=2))
    assert_equal(floor(FixedPoint48x16(from_float=1.5)), FixedPoint48x16(from_float=1))
    assert_equal(floor(FixedPoint48x16(from_float=2.5)), FixedPoint48x16(from_float=2))

def test_FixedPoint48x16__or__() raises:
    assert_equal(FixedPoint48x16(from_int=1) | FixedPoint48x16(from_int=2), FixedPoint48x16(from_int=3))
    assert_equal(FixedPoint48x16(from_int=2) | FixedPoint48x16(from_int=1), FixedPoint48x16(from_int=3))

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
