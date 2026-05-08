"""Provides FixedDType which are fixed point primitives for efficient integral 
based calculations.

These are useful for CPU based calculations.
"""

from std.sys.intrinsics import size_of
from std.math import floor, hypot, Floorable
from std.memory import memset_zero


comptime ByteSize: Int = 8


def _maximum_value[is_signed: Bool, size_bytes: Int]() -> Int:
    comptime if is_signed:
        return 2 ** (size_bytes * ByteSize - 1)
    else:
        return 2 ** (size_bytes * ByteSize)


def _maximum_repr_value[dtype: DType]() -> Int:
    comptime if dtype.is_signed():
        return 2 ** (size_of[dtype]() * ByteSize - 1)
    else:
        return 2 ** (size_of[dtype]() * ByteSize)


def _minimum_repr_value[dtype: DType]() -> Int:
    comptime if dtype.is_signed():
        return -_maximum_repr_value[dtype]()
    else:
        return 0


# TODO: see if we can add width to support simd ops.
struct FixedDType[
    dtype: DType,
    int_bytes: Int = size_of[dtype]() / 2,
    frac_bytes: Int = size_of[dtype]() - int_bytes,
](
    Comparable,
    Floatable,
    Floorable,
    ImplicitlyCopyable,
    Intable,
    Writable,
    Writable,
):
    """Represents FixedPoint scalars and enables fixed point arithmetic.

    Parameters:
        dtype: An integral type.
        int_bytes: The number of bytes used for representing the integral portion.
        frac_bytes: The number of bytes used for representing the fractional portion.

    If we suppose `dtype == uint32`, and we want to represent the value
    `65535.65535`. The default byte representation is if this fixed point value
    would be `270FF289`. The first `270F` is used for the integral portional,
    while that last `F289` is used for the fractional portion. In the cast of
    uint32, the last `5` of the fractional gets truncated.

    The integral portion is assumed to be the left portion of the bytes, while
    the fractional portion is the right portion of the bytes.
    """

    comptime int_bits = Self.int_bytes * ByteSize
    "Number of bits used to represent the integral portion of the value."
    comptime frac_bits = Self.frac_bytes * ByteSize
    "Number of bits used to represent the fractional portion of the value."
    comptime frac_scale = Float64(1 << Self.frac_bits)
    """The amount to scale fractional portion to.
    
    Cast to Float64 since `__mul__` is performed on Floatables.
    """

    comptime one = Self(1)
    """One value of `Self`.
    
    For example 16x16, 1 equals 65535.
    """
    comptime zero = Self(0)
    "Zero value of `Self`."
    comptime epsilon = Self(raw_value=1)
    "Smallest representable value of `Self`."

    comptime max_value = Self(raw_value=_maximum_repr_value[Self.dtype]())
    comptime min_value = Self(raw_value=_minimum_repr_value[Self.dtype]())
    comptime max_frac_value = Self(
        raw_value=Self.one.value - Self.epsilon.value
    )
    comptime max_int_value = Self(
        raw_value=_maximum_value[Self.dtype.is_signed(), Self.int_bytes]()
    )
    comptime min_int_value = Self(
        raw_value=0 if Self.dtype.is_unsigned() else -Self.max_int_value.value
    )
    # TODO: Maybe support varying width?
    var value: Scalar[Self.dtype]

    def __init__(out self, *, raw_value: Int):
        """Creates `Self` direct from `raw_value` keyword arg.

        Note: This does not attempt any scaling. The value is treated as a
        "raw" value. For example a raw `1` will be intpereted as `0.0006`
        """
        self.value = Scalar[Self.dtype](raw_value)

    def __init__(out self, *, raw_value: Scalar[Self.dtype]):
        """Creates `Self` direct from `raw_value` keyword arg.

        Note: This does not attempt any scaling. The value is treated as a
        "raw" value. For example a raw `1` will be intpereted as `0.0006`
        """
        self.value = raw_value

    def __init__(out self, value: Int):
        """Creates `Self` from `value` where `value` is an Int.

        The value is shifted left by `self.frac_bits`.
        """
        if value == 0:
            self = Self(raw_value=value)
        else:
            self = Self(raw_value=value << self.frac_bits)

    def __init__(out self, value: Float32):
        """Creates `Self` from `value` where `value` is a Float.

        The value is scaled by `Self.frac_scale` then cast to `Self.dtype`.

        Note this can truncate floating point values.
        """
        if value == 0.0:
            self = Self(raw_value=0)
        else:
            # TODO: Do we want to require no truncation by checking the float value
            # size and then provide a API call for unsafe truncating?
            self = Self(raw_value=Int(Float64(value) * Self.frac_scale))

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __lt__(self, other: Self) -> Bool:
        return self.value < other.value

    def __sub__(self, other: Self) -> Self:
        return {raw_value = self.value - other.value}

    def __add__(self, other: Self) -> Self:
        return {raw_value = self.value + other.value}

    def wide_mul[other_dtype: DType](self, other: Self) -> Self:
        """Performs fixed point multiplication.

        Multiplication is done via widing dtype, multiplying, and then shifting
        back to the original dtype.
        """
        comptime assert (
            other_dtype.is_integral()
        ), "Cannot widen multiply since `other_dtype` is not an integral type."
        comptime assert size_of[Self.dtype]() < size_of[other_dtype](), (
            "Cannot widen multiply since `other_dtype` is equal or smaller "
            "than `Self.dtype`."
        )
        comptime IntBigger = Scalar[other_dtype]
        var result = IntBigger(self.value) * IntBigger(other.value)
        return {
            raw_value = Scalar[Self.dtype](result >> IntBigger(Self.frac_bits))
        }

    def floor_div(self, other: Self) -> Self:
        """Integer division that rounds fractional portion towards zero."""
        var result = self.floor_div_raw(other)
        return {raw_value = result << Scalar[Self.dtype](Self.frac_bits)}

    def floor_div_raw(self, other: Self) -> Scalar[Self.dtype]:
        """Integer division that rounds fractional portion towards zero.

        Returns the raw value instead of fixed point equivolent.
        """
        return self.value / other.value

    def negative_floor_div(self, other: Self) -> Self:
        """Integer division that rounds fractional portion towards -infinity."""
        if (self.value < 0) == (other.value < 0):
            return self.floor_div(other)

        var result = self.negative_floor_div_raw[check=False](other)
        return {raw_value = result << Scalar[Self.dtype](Self.frac_bits)}

    def negative_floor_div_raw[
        check: Bool = True
    ](self, other: Self) -> Scalar[Self.dtype]:
        """Integer division that rounds fractional portion towards -infinity.

        Returns the raw value instead of fixed point equivolent.
        """
        # NOTE: Avoid checking twice (ref negative_floor_div)
        comptime if check:
            if (self.value < 0) == (other.value < 0):
                return self.floor_div_raw(other)

        # +1 or -1 depending on the sign of b.
        var sign = 1 - Scalar[Self.dtype](other.value < 0) * 2
        return (self.value - other.value + sign) / other.value

    def wide_div[other_dtype: DType](self, other: Self) -> Self:
        """Performs fixed point division by widening to avoid truncation.

        Multiplication is done via widing dtype, multiplying, and then shifting
        back to the original dtype.
        """
        comptime assert (
            other_dtype.is_integral()
        ), "Cannot widen multiply since `other_dtype` is not an integral type."
        comptime assert size_of[Self.dtype]() < size_of[other_dtype](), (
            "Cannot widen multiply since `other_dtype` is equal or smaller "
            "than `Self.dtype`."
        )
        comptime IntBigger = Scalar[other_dtype]
        var result = (
            IntBigger(self.value) << IntBigger(Self.frac_bits)
        ) / IntBigger(other.value)
        return {raw_value = Scalar[Self.dtype](result)}

    def __mod__(self, other: Self) -> Self:
        return {raw_value = self.value % other.value}

    #     def slow_div(self, other: Self) -> Self:
    #         """Floating point division of FixedPoint values.

    #         This is explicit instead of `__div__` since the purpose of FixedPoint
    #         values is fast integer arithmetic operations.
    #         """
    #         return Self(Float64(self.value) / Float64(other.value))

    #     def __truediv__(self, other: Self) -> Self:
    #         return {self.value / other.value}

    def __truediv__(self, other: Int) -> Self:
        return {raw_value = self.value / Scalar[Self.dtype](other)}

    def __mul__(self, other: Int) -> Self:
        return {raw_value = self.value * Scalar[Self.dtype](other)}

    def __and__(self, other: Self) -> Self:
        return {raw_value = self.value & other.value}

    def __rshift__(self, rhs: Int) -> Self:
        return {raw_value = self.value >> Scalar[Self.dtype](rhs)}

    def __int__(self) -> Int:
        "Returns the non-fixed point integral value of the fixed point value."
        return Int(self.value >> Scalar[Self.dtype](Self.frac_bits))

    def __float__(self) -> Float64:
        "Returns the non-fixed point floating point value of the fixed point value."
        return Float64(self.value) / Self.frac_scale

    def frac(self) -> Self:
        """Returns only the fractional part of the value."""
        return self & (Self.one - Self.epsilon)

    def __neg__(self) -> Self:
        return {raw_value = -self.value}

    def __iadd__(mut self, other: Self):
        self.value += other.value

    def __isub__(mut self, other: Self):
        self.value -= other.value

    def __floor__(self) -> Self:
        return {raw_value = self.value & ~(Self.max_frac_value.value)}

    def __or__(self, other: Self) -> Self:
        return {raw_value = self.value | other.value}


comptime FixedPoint48x16 = FixedDType[DType.int64, 6]
"""A 48x16 FixedPoint integer.

Where:
- The first 48 bits are the integral
- The last 16 bits are the fractional
"""
comptime FixedPoint16x16 = FixedDType[DType.int32]
"""A 16x16 FixedPoint integer.

Where:
- The first 16 bits are the integral
- The last 16 bits are the fractional
"""

comptime FixedInt = FixedPoint16x16
"""The default fixed int representation."""
