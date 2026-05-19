from std.math import floor
from momanim.rasterization.fixed_dtype import (
    FixedDType,
    FixedPoint16x16,
    FixedPoint48x16,
    FixedInt,
)


@fieldwise_init
struct PixelSampling[offset: Int, n: Int = 8](Writable):
    comptime samples_per_axis: Int = (1 << Self.n / 2) + Self.offset
    """Number of subpixel samples along one axis.

    Defaults:
    - X: 17 columns
    - Y: 15 columns
    """
    comptime step_size: FixedInt = FixedInt.one / Self.samples_per_axis
    "Length of each regular subpixel step."
    comptime step_span: FixedInt = Self.step_size * (Self.samples_per_axis - 1)
    """Total length covered by the regular subpixel steps.
    
    For example:
    - If the total subpixel length is 35 and FixedInt.one is 35 (for this example).
    - If there are 17 sub pixel segments.
    - Then step_size will be 2, truncated since floating point would yield 2.058.
    - Then common len will be 34. Note that this is -1 less than the needed 35.
    - Then the remainder will be 1.

    The remainder is of a different value of step size since it needs to handle 
    off-by-one error. We split it
    """
    comptime step_remainder: FixedInt = FixedInt.one - Self.step_span
    """Leftover fixed-point units after dividing the pixel into regular steps.

    Integer division usually leaves a small remainder. For example,
    65536 / 15 = 4369, and 4369 * 15 = 65535.

    Rather than making only the final step longer, we split the leftover
    units between the first and last step:
    `first_step, step_size, step_size, ..., step_size, last_step`
    """
    comptime first_step_size: FixedInt = Self.step_remainder / 2
    comptime last_step_size: FixedInt = Self.first_step_size
    comptime last_step_start: FixedInt = Self.first_step_size + Self.step_span
    """Start of the last subpixel row inside a pixel; Pixman calls this ``Y_FRAC_LAST``."""

    comptime sample_offset: FixedInt = Self.first_step_size - FixedInt.epsilon
    """Offset of the sample location from the first step size."""

    @staticmethod
    def coverage(x: Float32) -> Int:
        comptime if Self.n == 1:
            return 0
        else:
            return Self.coverage(FixedInt(from_float=x))

    @staticmethod
    def ceil(x: FixedInt) -> FixedInt:
        var f = x.frac()
        var i = floor(x)

        # Get which sample bin it is located in. e.g:
        # X axis has bins: [0, 17]
        # biased toward the ceiling bin instead of the floor.

        # TODO: it would probably be easier to just have these operate as
        # ints...
        var sample_bin = (
            (f - Self.first_step_size) + Self.step_size - FixedInt.epsilon
        ).negative_floor_div_raw(Self.step_size)
        # Get the sample location (value). This is the ceiled value
        # that should be the starting value of the bin.
        var sample_loc: FixedInt = {
            raw_value = sample_bin * Self.step_size.value
            + Self.first_step_size.value
        }

        # Determine whether this belongs to a completely different pixel.
        if sample_loc > Self.last_step_start:
            # Avoid integral overflow if we are at the maximum value.
            if i.value == FixedInt.max_value.value - 1:
                # TODO: Should we add an assertion here? I'm not sure I want this
                # just "setting at the sample loc". If this happens there is
                # probably something worst happening.
                sample_loc = FixedInt.max_frac_value
            else:
                # Wrap around to the next pixel, starting at that pixel's
                # first step loc.
                sample_loc = Self.first_step_size
                i += FixedInt.one
        return i | sample_loc

    @staticmethod
    def floor(x: FixedInt) -> FixedInt:
        comptime min_allowable_value = FixedInt.min_value.value + Scalar[
            x.dtype
        ](x.dtype.is_signed())
        var f = x.frac()
        var i = floor(x)
        # Reference the comments in the ceil function for intuition.
        var sample_bin = FixedInt(
            raw_value=(
                f - FixedInt.epsilon - Self.first_step_size
            ).negative_floor_div_raw(Self.step_size)
        )
        sample_loc = (
            sample_bin.fixed_mul[DType.int64](Self.step_size)
            + Self.first_step_size
        )

        if sample_loc < Self.first_step_size:
            if i.value == min_allowable_value:
                # TODO: Ref `ceil`, same issue.
                sample_loc = FixedInt.zero
            else:
                sample_loc = Self.last_step_start
                i -= FixedInt.one
        return i | sample_loc

    @staticmethod
    def coverage(x: FixedInt) -> Int:
        comptime if Self.n == 1:
            return 0
        else:
            # If x.frac() is 0:
            # (x.frac() + first part) / step size == 0
            # If x.frac() is 99 (like 5.99):
            # (x.frac() + first part) / step size == 17
            return Int(
                (x.frac() + Self.first_step_size).floor_div(Self.step_size)
            )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "(",
            "samples_per_axis=",
            Self.samples_per_axis,
            ", ",
            "step_size=",
            Self.step_size,
            ", ",
            "remainder=",
            Self.step_remainder,
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
