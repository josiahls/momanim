"""Provides FixedPoint int pirmitves for efficient int based calculations.

Many libraries and algoorithms use int operations for calculations. 
Floating points are converted into fixed point values where their fraction parts
are maintained.
"""

from std.sys.intrinsics import size_of
from std.math import floor


comptime ByteSize = 8


trait FixedPointType:
    pass


struct FixedPoint[
    dtype: DType,
    integral_portion: Scalar[dtype] = Scalar[dtype](size_of[dtype]() / 2),
](Comparable, ImplicitlyCopyable, Intable, Writable):
    """Represents FixedPoint scalars and enables fixed point arithmetic.

    Parameters:
        dtype: An integral type.
        integral_portion: The number of bytes used for representing the integral portion.
            If we suppose `dtype == uint32`, then the bit representation is:

            `FFFF`. The first `FF` is used for the integral portional, while that last `FF`
            is used for the fractional portion.

            It is important to note that the integral portion is assumed to be the
            left portion of the bits.
    """

    comptime scale_int_value = Scalar[Self.dtype](
        Self.integral_portion * ByteSize
    )
    comptime scale_float_value = Float32(2**Self.scale_int_value)

    comptime one = FixedPoint[Self.dtype, Self.integral_portion](1)
    comptime e = FixedPoint[Self.dtype, Self.integral_portion](
        Scalar[Self.dtype](1)
    )

    var value: Scalar[Self.dtype]

    def __init__(out self, value: Scalar[Self.dtype]):
        self.value = value

    def __init__(out self, value: Int):
        self.value = Scalar[Self.dtype](value) << Self.scale_int_value

    def __init__(out self, value: Float32):
        self.value = Scalar[Self.dtype](value * Self.scale_float_value)

    def __init__(out self, value: Float64):
        self.value = Scalar[Self.dtype](value * Float64(Self.scale_float_value))

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __lt__(self, other: Self) -> Bool:
        return self.value < other.value

    def __sub__(self, other: Self) -> Self:
        return Self(self.value - other.value)

    def __mod__(self, other: Self) -> Self:
        return Self(self.value % other.value)

    def slow_div(self, other: Self) -> Self:
        return Self(Float64(self.value) / Float64(other.value))

    # def __div__(self, other: Self) -> Self:
    #     return {self.value / other.value}

    def __truediv__(self, other: Self) -> Self:
        return {self.value / other.value}

    def __and__(self, other: Self) -> Self:
        return Self(self.value & other.value)

    def binary_div(self, pow_of_2: Int) -> Self:
        return {self.value >> Scalar[Self.dtype](pow_of_2)}

    def __int__(self) -> Int:
        return Int(self.value)

    def to_real_int(self) -> Int:
        return Int(self.value >> Self.scale_int_value)

    def to_real_float(self) -> Float32:
        return Float32(self.value) / Self.scale_float_value

    def get_fractional_part(self) -> Self:
        return self & (Self.one - Self.e)


comptime FixedPoint16x16 = FixedPoint[DType.uint32]
"""A 16x16 FixedPoint integer.

Where:
- The first 16 bits are the integral
- The last 16 bits are the fractional
"""

comptime FixedInt = FixedPoint16x16
"""The default fixed int representation.
"""
