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
        integral_portion: The number of bits used for representing the integral portion.
            If we suppose `dtype == uint32`, then the bit representation is:

            `FFFF`. The first `FF` is used for the integral portional, while that last `FF`
            is used for the fractional portion.

            It is important to note that the integral portion is assumed to be the
            left portion of the bits.
    """

    comptime scale_int_value = Scalar[Self.dtype](
        Self.integral_portion * ByteSize
    )
    comptime scale_float_value = Float32(1 << Self.scale_int_value)

    comptime one = FixedPoint[Self.dtype, Self.integral_portion](1)
    comptime zero = FixedPoint[Self.dtype, Self.integral_portion](0)
    comptime e = FixedPoint[Self.dtype, Self.integral_portion](
        Scalar[Self.dtype](1)
    )
    "Smallest representable value of `FixedPoint`."

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

    def __add__(self, other: Self) -> Self:
        return Self(self.value + other.value)

    def __mul__(self, other: Self) -> Self:
        return Self(self.value * other.value)

    def __mul__(self, other: Int) -> Self:
        return Self(self.value * Scalar[Self.dtype](other))

    def __mod__(self, other: Self) -> Self:
        return Self(self.value % other.value)

    def slow_div(self, other: Self) -> Self:
        """Floating point division of FixedPoint values.

        This is explicit instead of `__div__` since the purpose of FixedPoint
        values is fast integer arithmetic operations.
        """
        return Self(Float64(self.value) / Float64(other.value))

    def __truediv__(self, other: Self) -> Self:
        return {self.value / other.value}

    def __truediv__(self, other: Int) -> Self:
        # TODO: There has to be a nicer way to handle this.
        return {self.value / Scalar[Self.dtype](other)}

    def __and__(self, other: Self) -> Self:
        return Self(self.value & other.value)

    def __rshift__(self, pow_of_2: Int) -> Self:
        return {self.value >> Scalar[Self.dtype](pow_of_2)}

    def __int__(self) -> Int:
        return Int(self.value)

    def to_real_int(self) -> Int:
        return Int(self.value >> Self.scale_int_value)

    def to_real_float(self) -> Float32:
        return Float32(self.value) / Self.scale_float_value

    def get_fractional_part(self) -> Self:
        return self & (Self.one - Self.e)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("(", self.value, ", real:", self.to_real_float(), ")")


comptime FixedPoint16x16 = FixedPoint[DType.uint32]
"""A 16x16 FixedPoint integer.

Where:
- The first 16 bits are the integral
- The last 16 bits are the fractional
"""

comptime FixedInt = FixedPoint16x16
"""The default fixed int representation.
"""


@fieldwise_init
struct PixelSampling[offset: Int, n: Int = 8](Writable):
    comptime samples_per_pixel: Int = (1 << Self.n / 2) + Self.offset
    """The number of rows and columns in a subpixel area.

    Default usage:
    - X direction: 17 columns
    - Y direction: 15 columns
    """
    comptime step_size: FixedInt = FixedInt.one / Self.samples_per_pixel
    "A single unit step repsenting the length of a row or column."
    comptime remainder: FixedInt = FixedInt.one - Self.step_size * (
        Self.samples_per_pixel - 1
    )
    """The remaining coverage units of which does not equal Self.step_size.
    
    Pixel coverage is handled via.:

    `first part, step_size, step_size, ..., step_size, last part`.

    N samples for X is 15 and Y is 17. This is so max coverage can be represented
    as 15 * 17 = 255 which is the most "equal" x and y coverage we can represent
    that cleanly multiplies to 255. 

    For example if `Self.step_size` is `65536 / 15 = 4369 int`

    So each "sample row y" per pixel is 4369 units long. 

    We fail to recover the original total pixel length since 4369 * 15 = 65535.

    We have some alternatives:
    - Deal with the end of the pixel being a 1 unit longer than the others
    Or
    - Place that "extra" unit to be in the center of the pixel instead.

    We opt for the second option. `remainder` is the "slightly larger" step size.
    We divide it in half and distribute it over the start and end of the pixel.
    """
    comptime first_step_size: FixedInt = Self.remainder / 2
    comptime last_step_start: FixedInt = Self.first_step_size + Self.step_size * (
        Self.samples_per_pixel - 1
    )
    """Start of the last step."""

    @staticmethod
    def coverage(x: Float32) -> Int:
        comptime if Self.n == 1:
            return 0
        else:
            # If x.frac() is 0:
            # (x.frac() + first part) / step size == 0
            # If x.frac() is 99 (like 5.99):
            # (x.frac() + first part) / step size == 17
            return Int(
                (FixedInt(x).get_fractional_part() + Self.first_step_size)
                / Self.step_size
            )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "(",
            "samples_per_pixel=",
            Self.samples_per_pixel,
            ", ",
            "step_size=",
            Self.step_size,
            ", ",
            "remainder=",
            Self.remainder,
            ", ",
            "first_step_size=",
            Self.first_step_size,
            ", ",
            "last_step_start=",
            Self.last_step_start,
            ", ",
            ")",
        )


comptime XPixelSampling = PixelSampling[1]
comptime YPixelSampling = PixelSampling[-1]
