from momanim.mobject.geometry import Point2d, Triangle2d, Trapezoid2d, Vector2d
from momanim.stdlib_extensions import Enumable
from std.sys.intrinsics import size_of
from std.math import floor, hypot, ceil, log2


comptime ByteSize = 8


struct LineType(Enumable):
    comptime dtype = Int
    var value: Self.dtype

    @implicit
    def __init__(out self, value: Self.dtype):
        self.value = value

    def __init__(out self, enum: Self):
        self.value = enum.value

    comptime DIRECT = Self(0)
    comptime FOUR_CONNECT = Self(1)
    comptime EIGHT_CONNECT = Self(2)
    comptime ANTI_ALIASED = Self(3)


struct CartessianPoint2d(Copyable, Writable):
    comptime X_AXIS = 0
    comptime Y_AXIS = 1

    var dep: Float32
    var indep: Float32
    var dep_axis: Int

    def __init__(out self, p: Point2d):
        self.dep = p.y
        self.indep = p.x
        self.dep_axis = Self.Y_AXIS

    def __init__(out self, dep: Float32, indep: Float32, dep_axis: Int):
        self.dep = dep
        self.indep = indep
        self.dep_axis = dep_axis

    def __init__(out self, p: Self):
        self.dep = p.dep
        self.indep = p.indep
        self.dep_axis = p.dep_axis

    def __sub__(self, other: Self) -> Self:
        assert (
            self.dep_axis == other.dep_axis
        ), "Dependent axes must be the same"
        return {self.dep - other.dep, self.indep - other.indep, self.dep_axis}

    def swap_axis(mut self):
        if self.dep_axis == Self.X_AXIS:
            self.dep_axis = Self.Y_AXIS
        else:
            self.dep_axis = Self.X_AXIS
        self.dep, self.indep = self.indep, self.dep

    def to_point2d(self) -> Point2d:
        if self.dep_axis == Self.X_AXIS:
            return Point2d(self.dep, self.indep)
        else:
            return Point2d(self.indep, self.dep)


struct CartessianVector2d(Copyable, Writable):
    """Similar to Vector2d` however describes "dependent" and "independent"
    axis.

    """

    var p1: CartessianPoint2d
    var p2: CartessianPoint2d

    def __init__(out self, v: Vector2d):
        self.p1 = CartessianPoint2d(v.p1)
        self.p2 = CartessianPoint2d(v.p2)

    def magnitude(self) -> CartessianPoint2d:
        return self.p2 - self.p1

    def swap_axis(mut self):
        self.p1.swap_axis()
        self.p2.swap_axis()


struct Tessalator:
    var image_ptr: UnsafePointer[UInt8, MutExternalOrigin]
    var mask: UnsafePointer[UInt8, MutExternalOrigin]
    """Draws occur first in the mask buffer then get applied to the image_ptr.
    
    The mask buffer is a `linesize x h x 1` buffer ranging 0 - 255, where 0
    is background.
    
    """
    var linesize: Int
    var w: Int
    var h: Int
    var hypot: Float32
    """Longest drawable straight line in the image."""

    # NOTE: In the paper: An Efficient Antialiasing Technique by Wu et al.,
    # they note that 32 (gray) scales are sufficient for most cases.
    # So m = 5 where 2^m = 32. `m` is renamed to ``gray_scales``
    comptime gray_scales = 5
    var gray_scale_precision: Int
    var n_gray_scale_precision_bytes: Int
    """Number of bytes needed to represent the gray scale precision."""

    def __init__(
        out self,
        image_ptr: UnsafePointer[UInt8, MutExternalOrigin],
        linesize: Int,
        w: Int,
        h: Int,
    ):
        self.image_ptr = image_ptr
        self.linesize = linesize
        self.w = w
        self.h = h
        self.mask = alloc[UInt8](self.linesize * h)

        self.hypot = ceil(hypot(Float32(w), Float32(h)))
        # log2(hypot) = how many bytes are needed to represent the length?
        # Add the bytes needed to represent the grayscales.
        self.gray_scale_precision = Int(
            ceil(log2(self.hypot)) + self.gray_scales + 1
        )
        self.n_gray_scale_precision_bytes = Int(
            ceil(Float32(self.gray_scale_precision) / Float32(ByteSize))
        )
        self.gray_scale_precision = self.n_gray_scale_precision_bytes * ByteSize

    def draw_intensity(mut self, x: Int, y: Int, intensity: UInt8):
        self.mask.store(val=intensity, offset=Int(round(y * self.linesize + x)))

    def commit(mut self):
        for y in range(self.h):
            for x in range(self.linesize):
                self.image_ptr.store(
                    val=self.mask.load(offset=y * self.linesize + x),
                    offset=y * self.linesize + x,
                )

    def draw_point[
        color_width: Int
    ](mut self, p: Point2d, color: SIMD[UInt8.dtype, color_width]):
        # TODO: Debating where we should check dimensions.
        self.mask.store(
            val=color, offset=Int(round(p.y * Float32(self.linesize) + p.x))
        )

    def draw_vector[
        color_width: Int
    ](
        mut self,
        v: Vector2d,
        color: SIMD[UInt8.dtype, color_width],
        line_type: LineType = LineType.ANTI_ALIASED,
    ):
        if self.n_gray_scale_precision_bytes == 1:
            self._draw_vector[DType.uint8](v, line_type)
        elif self.n_gray_scale_precision_bytes == 2:
            self._draw_vector[DType.uint16](v, line_type)
        elif self.n_gray_scale_precision_bytes == 3:
            self._draw_vector[DType.uint32](v, line_type)
        elif self.n_gray_scale_precision_bytes == 4:
            self._draw_vector[DType.uint64](v, line_type)
        else:
            assert False, "Invlid n_gray_scale_precision_bytes: {}".format(
                self.n_gray_scale_precision_bytes
            )

    def _draw_vector[
        T: DType
    ](mut self, v: Vector2d, line_type: LineType = LineType.ANTI_ALIASED,):
        comptime assert T.is_integral()
        comptime assert T.is_unsigned()
        comptime UIntT = Scalar[T]
        var cartessian_v = CartessianVector2d(v)

        var mag = cartessian_v.magnitude()
        if abs(mag.dep) > abs(mag.indep):
            cartessian_v.swap_axis()
            mag.swap_axis()

        var k: Float32 = abs(mag.dep / mag.indep)

        var direct_inc = Float32(-1.0 if mag.indep < 0 else 1.0)
        var depend_inc = Float32(-1.0 if mag.dep < 0 else 1.0)
        assert k <= 1, "k must be less than or equal to 1 got: {}".format(k)
        assert k >= 0, "k must be greater than or equal to 0 got: {}".format(k)

        var D: UIntT = 0
        var new_D: UIntT
        # NOTE: Converts `k` into an integer step.
        var d: UIntT = UIntT(
            floor(k * Float32(2**self.gray_scale_precision) + 0.5)
        )
        var inc_depend_axis = k == 1

        def _scale_coverage[
            m: Int
        ](color: SIMD[UInt8.dtype, 1], coverage: UInt8) -> SIMD[UInt8.dtype, 1]:
            """Scales a grayscale color by an 8-bit coverage."""
            var scaled = (SIMD[T, 1](color) * SIMD[T, 1](coverage)) >> m
            return SIMD[UInt8.dtype, 1](scaled)

        self.draw_point[1](cartessian_v.p1.to_point2d(), 255)
        self.draw_point[1](cartessian_v.p2.to_point2d(), 255)
        while (
            cartessian_v.p1.indep
            <= cartessian_v.p2.indep if direct_inc
            > 0 else cartessian_v.p1.indep
            >= cartessian_v.p2.indep
        ):
            cartessian_v.p1.indep += direct_inc
            cartessian_v.p2.indep -= direct_inc

            if k != 1:
                new_D = D + d
                inc_depend_axis = new_D < D
                D = new_D
            if inc_depend_axis:
                cartessian_v.p1.dep += depend_inc
                cartessian_v.p2.dep -= depend_inc

            if k == 1:
                self.draw_point(
                    cartessian_v.p1.to_point2d(), SIMD[UInt8.dtype, 1](255)
                )
                self.draw_point(
                    cartessian_v.p2.to_point2d(), SIMD[UInt8.dtype, 1](255)
                )
                continue

            var coverage: UInt8 = UInt8(
                D >> UIntT(self.gray_scale_precision - self.gray_scales)
            )  # Same as floor(D / 2^{n - m})
            var inverse_coverage: UInt8 = (
                UInt8((2**self.gray_scales) - 1) - coverage
            )

            var p1_offset = CartessianPoint2d(cartessian_v.p1)
            p1_offset.dep += depend_inc
            var p2_offset = CartessianPoint2d(cartessian_v.p2)
            p2_offset.dep -= depend_inc

            self.draw_point(
                cartessian_v.p1.to_point2d(),
                _scale_coverage[self.gray_scales](255, inverse_coverage),
            )
            self.draw_point(
                cartessian_v.p2.to_point2d(),
                _scale_coverage[self.gray_scales](255, inverse_coverage),
            )
            self.draw_point(
                p1_offset.to_point2d(),
                _scale_coverage[self.gray_scales](255, coverage),
            )
            self.draw_point(
                p2_offset.to_point2d(),
                _scale_coverage[self.gray_scales](255, coverage),
            )
