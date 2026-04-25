from momanim.mobject.geometry import Point2d, Triangle2d, Trapezoid2d, Vector2d
from momanim.stdlib_extensions import Enumable
from std.sys.intrinsics import size_of
from std.math import floor, hypot, ceil, log2
from momanim.mobject.bezier_curve import (
    QuadBezierCurve,
    decompose_bezier_curve,
    Point,
)
from std.memory import memset_zero

comptime ByteSize = 8


def decompose_curves_to_vectors[
    dtype: DType
](
    curves: List[QuadBezierCurve[dtype]], thickness: Float32, tolarence: Int = 1
) raises -> List[Vector2d]:
    """Draws a ribbon of `TriQuad`s along a line whose width is `thickness`."""
    comptime assert dtype.is_floating_point()
    var vectors = List[Vector2d]()
    var prev_point: Optional[Point[Float64.dtype]] = None
    # var point: Point[Float64.dtype]
    var points = List[Point[Float64.dtype]]()

    for curve in curves:
        decompose_bezier_curve(points, curve)

    for point in points:
        # TODO: Do we need to do and prev_point[] != point?
        # print("point: ", point)
        if prev_point:
            if round(prev_point[].coords[0]) == round(
                point.coords[0]
            ) and round(prev_point[].coords[1]) == round(point.coords[1]):
                # print("Skipping duplicate point: ", point.coords)
                continue
            vectors.append(
                Vector2d(
                    Point2d(
                        x=Float32(prev_point[].coords[0]),
                        y=Float32(prev_point[].coords[1]),
                    ),
                    Point2d(
                        x=Float32(point.coords[0]), y=Float32(point.coords[1])
                    ),
                )
            )
        prev_point = point.copy()

    return vectors^


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


struct Span2d(Copyable, Writable):
    var p0: Point2d
    var p1: Point2d

    def __init__(out self, v: Vector2d):
        self.p0 = v.p1.copy()
        self.p1 = v.p2.copy()


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
        memset_zero(self.mask, self.linesize * h)

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

    def commit[width: Int](mut self, color: SIMD[UInt8.dtype, width]):
        comptime assert width == 1 or width == 4
        for y in range(self.h):
            for x in range(self.linesize):
                var mask_offset = y * self.linesize + x
                var offset = y * self.linesize * width + x * width
                var c_b_f_b = self.image_ptr.load[width](offset=offset)
                var f_a = self.mask.load(offset=mask_offset)
                # TODO: Need to handle Porder-Duff operations generally.
                # This for now is: A over B Porter Duff op hardcoded.
                var alpha: UInt8
                comptime if width == 1:
                    alpha = c_b_f_b[0]
                else:
                    alpha = c_b_f_b[3]
                # TODO: So ugly. Also wondering can we use the rshifting to maintain
                # the int representation? Casting to float can't be good here.

                # TODO: Also can't we premultiply earlier? Cant we use SIMD operations
                # to do this quickly?
                var alpha_a_float: Float32 = Float32(f_a) / 255.0
                var alpha_b_float: Float32 = Float32(alpha) / 255.0

                # TODO: This can be done earlier
                var pre_multiplied_a = (
                    SIMD[Float32.dtype, width](color) * alpha_a_float
                )
                var pre_multiplied_b = (
                    SIMD[Float32.dtype, width](c_b_f_b) * alpha_b_float
                )

                var dest_color = pre_multiplied_a + pre_multiplied_b * (
                    1 - alpha_a_float
                )

                self.image_ptr.store(
                    val=SIMD[UInt8.dtype, width](dest_color), offset=offset
                )

    def draw_point[
        color_width: Int
    ](mut self, p: Point2d, color: SIMD[UInt8.dtype, color_width]):
        # TODO: Debating where we should check dimensions.
        # TODO: We need to add blend methods. For now, I think it should be
        # max alpha.
        var offset = Int(round(p.y)) * self.linesize + Int(round(p.x))

        # var dest = color.cast[Float32.dtype]() + self.mask.load(offset).cast[Float32.dtype]() * (1 - color.cast[Float32.dtype]() / 255.0)
        # self.mask.store(val=dest.cast[UInt8.dtype](), offset=offset)
        if color > self.mask.load(offset):
            self.mask.store(val=color, offset=offset)

    def draw_vector_scanline(
        mut self,
        v: Vector2d,
        line_type: LineType = LineType.ANTI_ALIASED,
    ):
        var span = Span2d(v)

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
        print("v: ", v)

        var cartessian_v = CartessianVector2d(v)

        var mag = cartessian_v.magnitude()
        # If y > x
        if abs(mag.dep) > abs(mag.indep):
            cartessian_v.swap_axis()
            mag.swap_axis()

        var k: Float32 = abs(mag.dep / mag.indep)

        var indep_inc = Float32(-1.0 if mag.indep < 0 else 1.0)
        var depend_inc = Float32(-1.0 if mag.dep < 0 else 1.0)
        assert (
            k <= 1
        ), "k must be less than or equal to 1 got: {} for vector: {}".format(
            k, v
        )
        assert (
            k >= 0
        ), "k must be greater than or equal to 0 got: {} for vector: {}".format(
            k, v
        )

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
            # TODO: tbh I'm not a fan of this. Also the >> m I think is wrong,
            # only scaling up to 247 instead of 255.
            var scaled = (SIMD[T, 1](color) * SIMD[T, 1](coverage)) >> m
            return SIMD[UInt8.dtype, 1](scaled)

        var coverage: UInt8 = UInt8(
            d >> UIntT(self.gray_scale_precision - self.gray_scales)
        )  # Same as floor(D / 2^{n - m})

        self.draw_point[1](
            cartessian_v.p1.to_point2d(),
            _scale_coverage[self.gray_scales](255, coverage),
        )
        var end_endpoint = cartessian_v.p2.to_point2d().copy()

        while (
            cartessian_v.p1.indep
            <= cartessian_v.p2.indep if indep_inc
            > 0 else cartessian_v.p1.indep
            >= cartessian_v.p2.indep
        ):
            cartessian_v.p1.indep += indep_inc
            cartessian_v.p2.indep -= indep_inc

            if k != 1 and d != 0:
                new_D = D + d
                inc_depend_axis = new_D < D
                D = new_D
            if inc_depend_axis:
                cartessian_v.p1.dep += depend_inc
                cartessian_v.p2.dep -= depend_inc

            if k == 1 or k == 0:
                self.draw_point(
                    cartessian_v.p1.to_point2d(), SIMD[UInt8.dtype, 1](255)
                )
                self.draw_point(
                    cartessian_v.p2.to_point2d(), SIMD[UInt8.dtype, 1](255)
                )
                continue

            coverage: UInt8 = UInt8(
                D >> UIntT(self.gray_scale_precision - self.gray_scales)
            )  # Same as floor(D / 2^{n - m})
            var inverse_coverage: UInt8 = (
                UInt8((2**self.gray_scales) - 1) - coverage
            )

            var p1_offset = CartessianPoint2d(cartessian_v.p1)
            p1_offset.dep += depend_inc
            var p2_offset = CartessianPoint2d(cartessian_v.p2)
            p2_offset.dep -= depend_inc

            # print("drawing: cartessian_v.p1: ", cartessian_v.p1.to_point2d(), "cartessian_v.p2: ", cartessian_v.p2.to_point2d())

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
        self.draw_point[1](
            end_endpoint, _scale_coverage[self.gray_scales](255, coverage)
        )
