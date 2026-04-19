from momanim.mobject.geometry import Point2d, Triangle2d, Trapezoid2d, Vector2d
from momanim.stdlib_extensions import Enumable
from std.sys.intrinsics import size_of
from std.math import floor, hypot, ceil, log2


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


def draw_point[
    color_width: Int
](
    p: Point2d,
    ptr: UnsafePointer[UInt8, MutExternalOrigin],
    color: SIMD[UInt8.dtype, color_width],
    linesize: Int,
    w: Int,
    h: Int,
):
    # TODO: Debating where we should check dimensions.
    # print("draw point: ", p.y, "x: ", p.x)
    ptr.store(val=color, offset=Int(round(p.y * Float32(linesize) + p.x)))


def draw_vector[
    color_width: Int
](
    v: Vector2d,
    ptr: UnsafePointer[UInt8, MutExternalOrigin],
    color: SIMD[UInt8.dtype, color_width],
    linesize: Int,
    w: Int,
    h: Int,
    line_type: LineType = LineType.ANTI_ALIASED,
):
    """Uses Wu's Line Drawning Algorithm.

    Args:
        v: The vector to draw.
        ptr: The pointer to the framebuffer.
        color: The color to draw the vector in RGBA.
        linesize: The line size of a single row in an image in the `ptr`.
        w: The width of the image.
        h: The height of the image.
        line_type: The line type. TODO: This is hardcoded for now and always attempts
                                  anti aliasing.

    See:
    - https://dl.acm.org/doi/epdf/10.1145/122718.122734
    """
    # NOTE: In the paper: An Efficient Antialiasing Technique by Wu et al.,
    # they note that 32 (gray) scales are sufficient for most cases.
    # So m = 5 where 2^m = 32.
    comptime m = 5
    var L = ceil(hypot(Float32(w), Float32(h)))
    print("L: ", L)
    var n_precision = ceil(log2(L)) + m + 1
    print("n_precision: ", n_precision)
    var n = Int(n_precision)

    if 0 < n <= 8:
        n = 8
        _draw_vector[UInt8.dtype](
            v,
            ptr,
            color,
            linesize,
            w,
            h,
            n,
            m,
            line_type,
        )
    elif 8 < n <= 16:
        n = 16
        _draw_vector[UInt16.dtype](
            v,
            ptr,
            color,
            linesize,
            w,
            h,
            n,
            m,
            line_type,
        )
    elif 16 < n <= 32:
        n = 32
        _draw_vector[UInt32.dtype](
            v,
            ptr,
            color,
            linesize,
            w,
            h,
            n,
            m,
            line_type,
        )
    else:
        n = 64
        _draw_vector[UInt64.dtype](
            v,
            ptr,
            color,
            linesize,
            w,
            h,
            n,
            m,
            line_type,
        )


def _draw_vector[
    T: DType, color_width: Int
](
    v: Vector2d,
    ptr: UnsafePointer[UInt8, MutExternalOrigin],
    color: SIMD[UInt8.dtype, color_width],
    linesize: Int,
    w: Int,
    h: Int,
    n: Int,
    m: Int,
    line_type: LineType = LineType.ANTI_ALIASED,
):
    """Uses Wu's Line Drawning Algorithm.

    Args:
        v: The vector to draw.
        ptr: The pointer to the framebuffer.
        color: The color to draw the vector in RGBA.
        linesize: The line size of a single row in an image in the `ptr`.
        w: The width of the image.
        h: The height of the image.
        line_type: The line type. TODO: This is hardcoded for now and always attempts
                                  anti aliasing.

    See:
    - https://dl.acm.org/doi/epdf/10.1145/122718.122734
    """
    comptime assert T.is_integral()
    comptime assert T.is_unsigned()
    comptime UIntT = Scalar[T]
    # NOTE: We's algorithm assumes the points are adjacent e.g. 0 <= k <= 1.
    var mag = v.magnitude()
    var k = mag.y / mag.x
    assert k <= 1
    assert k >= 0
    # how do I select the int dtype needed for this?
    var D: UIntT = 0
    var new_D: UIntT
    # NOTE: Converts `k` into an integer.
    var d: UIntT = UIntT(floor(k * Float32(2**n) + 0.5))

    var x0 = v.p1.x
    var x1 = v.p2.x
    var y0 = v.p1.y
    var y1 = v.p2.y
    # print("init: x0: ", x0, "y0: ", y0, "x1: ", x1, "y1: ", y1)

    def _scale_coverage(
        # TODO: change to color width
        color: SIMD[UInt8.dtype, color_width],
        coverage: UInt8,
    ) -> SIMD[UInt8.dtype, color_width]:
        """Scales a grayscale color by an 8-bit coverage."""
        var scaled = (SIMD[T, color_width](color) * SIMD[T, 1](coverage)) >> m
        # print("scaled: ", scaled, "color: ", color, "coverage: ", coverage)
        return SIMD[UInt8.dtype, color_width](scaled)

    draw_point(v.p1, ptr, color, linesize, w, h)
    draw_point(v.p2, ptr, color, linesize, w, h)
    while x0 <= x1:
        x0 += 1
        x1 -= 1

        if k == 1:
            y0 += 1
            y1 -= 1

            draw_point(
                {x0, y0},
                ptr,
                color,
                linesize,
                w,
                h,
            )
            draw_point(
                {x1, y1},
                ptr,
                color,
                linesize,
                w,
                h,
            )
            continue

        new_D = D + d
        if new_D < D:
            y0 += 1
            y1 -= 1
        D = new_D

        var coverage = UInt8(D >> UIntT(n - m))
        var inverse_coverage = UInt8((2**m) - 1) - coverage

        # print("coverage: ", coverage, "inverse_coverage: ", inverse_coverage)

        # print("x0: ", x0, "y0: ", y0, "x1: ", x1, "y1: ", y1)

        # print("draw pont 1")
        draw_point(
            {x0, y0},
            ptr,
            _scale_coverage(color, inverse_coverage),
            linesize,
            w,
            h,
        )
        # print("draw pont 2")
        draw_point(
            {x1, y1},
            ptr,
            _scale_coverage(color, inverse_coverage),
            linesize,
            w,
            h,
        )
        # print("draw pont 3")
        draw_point(
            {x0, y0 + 1},
            ptr,
            _scale_coverage(color, coverage),
            linesize,
            w,
            h,
        )
        # print("draw pont 4")
        draw_point(
            {x1, y1 - 1},
            ptr,
            _scale_coverage(color, coverage),
            linesize,
            w,
            h,
        )

        # print("D: ", D, "new_D: ", new_D, "coverage: ", coverage)
