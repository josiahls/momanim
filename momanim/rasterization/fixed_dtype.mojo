"""Provides FixedDType which are fixed point primitives for efficient integral 
based calculations.

These are useful for CPU based calculations.
"""

from std.sys.intrinsics import size_of
from std.math import floor, hypot, Floorable
from std.memory import memset_zero


comptime ByteSize: Int = 8


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

    #     def __truediv__(self, other: Int) -> Self:
    #         # TODO: There has to be a nicer way to handle this.
    #         return {self.value / Scalar[Self.dtype](other)}

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


# int64 backing for intermediates (see Pixman `pixman_fixed_48_16_t`), same **16 fractional
# bits** as `FixedInt`: second param is **bytes** of fractional part → 2 * 8 = 16 bits.
comptime FixedPoint48x16 = FixedDType[DType.int64, 6]
comptime FixedPoint16x16 = FixedDType[DType.int32]
"""A 16x16 FixedPoint integer.

Where:
- The first 16 bits are the integral
- The last 16 bits are the fractional
"""

comptime FixedInt = FixedPoint16x16
"""The default fixed int representation.
"""


# @fieldwise_init
# struct PixelSampling[offset: Int, n: Int = 8](Writable):
#     comptime samples_per_pixel: Int = (1 << Self.n / 2) + Self.offset
#     """The number of rows and columns in a subpixel area.

#     Default usage:
#     - X direction: 17 columns
#     - Y direction: 15 columns
#     """
#     comptime step_size: FixedInt = FixedInt.one / Self.samples_per_pixel
#     "A single unit step repsenting the length of a row or column."
#     comptime remainder: FixedInt = FixedInt.one - Self.step_size * (
#         Self.samples_per_pixel - 1
#     )
#     """The remaining coverage units of which does not equal Self.step_size.

#     Pixel coverage is handled via.:

#     `first part, step_size, step_size, ..., step_size, last part`.

#     N samples for X is 15 and Y is 17. This is so max coverage can be represented
#     as 15 * 17 = 255 which is the most "equal" x and y coverage we can represent
#     that cleanly multiplies to 255.

#     For example if `Self.step_size` is `65536 / 15 = 4369 int`

#     So each "sample row y" per pixel is 4369 units long.

#     We fail to recover the original total pixel length since 4369 * 15 = 65535.

#     We have some alternatives:
#     - Deal with the end of the pixel being a 1 unit longer than the others
#     Or
#     - Place that "extra" unit to be in the center of the pixel instead.

#     We opt for the second option. `remainder` is the "slightly larger" step size.
#     We divide it in half and distribute it over the start and end of the pixel.
#     """
#     comptime first_step_size: FixedInt = Self.remainder / 2
#     comptime last_step_start: FixedInt = Self.first_step_size + Self.step_size * (
#         Self.samples_per_pixel - 1
#     )
#     """Start of the last subpixel row inside a pixel; Pixman calls this ``Y_FRAC_LAST``."""

#     @staticmethod
#     def coverage(x: Float32) -> Int:
#         comptime if Self.n == 1:
#             return 0
#         else:
#             return Self.coverage(FixedInt(x))

#     @staticmethod
#     def div_floor(a: FixedInt, b: FixedInt) -> FixedInt:
#         """Pixman `DIV`: integer division rounded toward negative infinity."""
#         var av = Int(a.value)
#         var bv = Int(b.value)
#         var q = av / bv
#         var r = av % bv
#         if r != 0:
#             if (av < 0 and bv > 0) or (av > 0 and bv < 0):
#                 q -= 1
#         return FixedInt.cast(q)

#     @staticmethod
#     def ceil(x: FixedInt) -> FixedInt:
#         var f = x.get_fractional_part()
#         print("f", f)
#         var i = floor(x)
#         print("i", i)

#         var sample_loc = Self.div_floor(
#             f - Self.first_step_size + Self.step_size - FixedInt.e,
#             Self.step_size,
#         )
#         print("sample_loc", sample_loc)
#         sample_loc = sample_loc * Self.step_size + Self.first_step_size

#         if sample_loc > Self.last_step_start:
#             print("doing an adjustment")
#             if Int(i) == 32767:
#                 sample_loc = FixedInt.max_value
#             else:
#                 sample_loc = Self.first_step_size
#                 i += FixedInt.one
#         return i | sample_loc

#     @staticmethod
#     def floor(x: FixedInt) -> FixedInt:
#         var f = x.get_fractional_part()
#         var i = floor(x)

#         var sample_loc = Self.div_floor(
#             f - Self.first_step_size - FixedInt.e,
#             Self.step_size,
#         )
#         sample_loc = sample_loc * Self.step_size + Self.first_step_size

#         if sample_loc < Self.first_step_size:
#             if Int(i) == 4294934528:
#                 sample_loc = FixedInt.zero
#             else:
#                 sample_loc = Self.last_step_start
#                 i -= FixedInt.one
#         return i | sample_loc

#     @staticmethod
#     def coverage(x: FixedInt) -> Int:
#         comptime if Self.n == 1:
#             return 0
#         else:
#             # If x.frac() is 0:
#             # (x.frac() + first part) / step size == 0
#             # If x.frac() is 99 (like 5.99):
#             # (x.frac() + first part) / step size == 17
#             return Int(
#                 (x.get_fractional_part() + Self.first_step_size)
#                 / Self.step_size
#             )

#     def write_to(self, mut writer: Some[Writer]):
#         writer.write(
#             "(",
#             "samples_per_pixel=",
#             Self.samples_per_pixel,
#             ", ",
#             "step_size=",
#             Self.step_size,
#             ", ",
#             "remainder=",
#             Self.remainder,
#             ", ",
#             "first_step_size=",
#             Self.first_step_size,
#             ", ",
#             "last_step_start=",
#             Self.last_step_start,
#             ", ",
#             ")",
#         )


# comptime XPixelSampling = PixelSampling[1]
# comptime YPixelSampling = PixelSampling[-1]
