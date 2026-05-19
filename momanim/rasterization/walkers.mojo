from momanim.rasterization.fixed_dtype import FixedInt
from momanim.rasterization.geometry_2d import FixedPointEdge2d
from momanim.rasterization.subpixel_sampling import (
    XPixelSampling,
    YPixelSampling,
)

# TODO: At some point parameterize all of this.


@fieldwise_init
struct Edge2dWalker(Movable, Writable):
    """Defines required integer primitives to step along an edge.

    Note: The types are not FixedPoint themselves since the walker makes no
    effort to maintain scales during division or multiplication, effectively
    treating these values as very large integrals. Thus, to aovid confusion,
    they are stored as the whole integral of whatever fixed point dtype is being
    used.

    """

    comptime IntType = Scalar[FixedInt.dtype]
    comptime BiggerIntType = Scalar[DType.int64]

    var x: Self.IntType
    "The current `x` position."
    var dy: Self.IntType
    "The total change in the y axis."
    var sign_dx: Self.IntType
    var x_per_unit_dy: Self.IntType
    """Whole-number (integer) part of total x delta over total y delta.
    
    In raw fixed-point units (same encoding as the endpoints). 
    
    Not “x step per 1 raw increment of y” by itself;
    see Pixman ``e->stepx`` / remainder.
    """
    var x_remainder: Self.IntType
    """Fractional part of total x delta over total y delta, in raw fixed-point\
    units (same encoding as the endpoints).

    This is involved in calculating the error or drift as we increment y and x.
    """
    var error: Self.IntType
    """Error accumulator that increments `self.x` when `error >= 0`.
    
    Bresenham Line Algorithm style.
    """

    var error_step: Self.IntType
    var error_remainder_step: Self.IntType
    var step_x: Self.IntType
    var step_x_remainder: Self.IntType

    def __init__(out self, edge: FixedPointEdge2d):
        # TODO: This walker requires that top x,y and bot x,y are valid.
        var mag = edge.magnitude()
        var dx = mag.x.value
        self.x = edge.p0.x.value
        self.dy = mag.y.value
        assert self.dy >= 0, "`dy` magnitude must be positive, got: {}".format(
            self.dy
        )
        # NOTE: pixman uses some negation during division for
        # negative magnitudes. I beleive this is an artifact of
        # older architectures.
        self.x_per_unit_dy = dx / self.dy
        if dx >= 0:
            self.sign_dx = 1
            # NOTE: Per y unit step, we increment by `x_per_unit_dy`.
            # However there can be left over or drift.
            # x_remainder is the remaining units.
            # Cases such as vertical and diagonal have 0 remainder
            # since the ratio between dx and dy is a whole number. This is
            # also 0 for any slopes that divide evenly into each other.
            self.x_remainder = dx % self.dy
            # NOTE: This is a starting bias for the first step.
            self.error = self.dy * -1
        else:
            self.sign_dx = -1
            self.x_remainder = -dx % self.dy
            self.error = 0

        self.error_step = 0
        self.error_remainder_step = 0
        self.step_x = 0
        self.step_x_remainder = 0

        def init_steps(
            unit_step: Self.IntType,
            mut error_step: Self.IntType,
            mut step_x: Self.IntType,
        ) capturing:
            # Given unit_step, either YPixelSample.step_size or YPixelSample.step_remainder,
            # get the slope drift over the that step amount.
            var error_remainder = Self.BiggerIntType(
                self.x_remainder
            ) * Self.BiggerIntType(unit_step)
            # Similarly, get the total change in x units over unit_step.
            var x_per_unit_step = self.x_per_unit_dy * unit_step

            if error_remainder > 0:
                # if the error remainder for `unit_step` is > 0,
                # we need to determine the amount of extra change in x from the
                # accumulated remainder.
                var dy = Self.BiggerIntType(self.dy)
                # NOTE: Per y unit, get the amount of error due to the unit_step
                # NOTE: Truncated amount of error per dy
                var error_per_y_unit = error_remainder / dy
                error_remainder -= error_per_y_unit * dy
                var error_bump = error_per_y_unit * Self.BiggerIntType(
                    self.sign_dx
                )
                x_per_unit_step += Self.IntType(error_bump)

            error_step = Self.IntType(error_remainder)
            step_x = x_per_unit_step

        init_steps(YPixelSampling.step_size.value, self.error_step, self.step_x)
        init_steps(
            YPixelSampling.step_remainder.value,
            self.error_remainder_step,
            self.step_x_remainder,
        )

    def __init__(out self, edge: FixedPointEdge2d, start_y: FixedInt):
        self = Self(edge)
        self.step_n_units(start_y - edge.y_top())

    def step_n_units(mut self, n_units: FixedInt):
        self.x += n_units.value * self.x_per_unit_dy

        var unit_error = Self.BiggerIntType(self.error) + Self.BiggerIntType(
            n_units.value
        ) * Self.BiggerIntType(self.x_remainder)

        if n_units.value >= 0:
            if unit_error > 0:
                # TODO: Figure out where we really need bigger int ops.
                # /home/mojo_user/momanim/third_party/pixman/pixman/pixman-trap.c
                var dy = Self.BiggerIntType(self.dy)
                # TODO: this looks similar to the original initialization code
                # in init_steps above. Maybe extract this into a common function
                var units_x = (unit_error + dy - 1) / dy
                self.error = Self.IntType(unit_error - units_x * dy)
                self.x += Self.IntType(units_x) * self.sign_dx
        else:
            if unit_error <= Self.BiggerIntType(-self.dy):
                var dy = Self.BiggerIntType(self.dy)
                # TODO: this looks similar to the original initialization code
                # in init_steps above. Maybe extract this into a common function
                var units_x = (-unit_error) / dy
                self.error = Self.IntType(unit_error + units_x * dy)
                self.x -= Self.IntType(units_x) * self.sign_dx

    def reset_error(mut self):
        "If error > 0, then we increment x and reset error."
        if self.error > 0:
            self.error -= self.dy
            self.x += self.sign_dx

    def step(mut self):
        self.x += self.step_x
        self.error += self.error_step
        self.reset_error()

    def step_remainder(mut self):
        self.x += self.step_x_remainder
        self.error += self.error_remainder_step
        self.reset_error()
