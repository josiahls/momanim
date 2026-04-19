from std.math import atan2, atan, tan, sqrt
from momanim.mobject.polygram import MObject
from momanim.mobject.bezier_curve import (
    QuadBezierCurve,
    farin_rational_de_casteljau,
    Point,
    decompose_bezier_curve,
)


comptime CW = 0
comptime CCW = 1


struct Triangle[dtype: DType, dims: Int = 2, winding: Int = CW](
    Copyable, ImplicitlyCopyable, Movable
):
    var points: InlineArray[Scalar[Self.dtype], 3 * Self.dims]

    def __init__(
        out self,
        p1: Point[Self.dtype],
        p2: Point[Self.dtype],
        p3: Point[Self.dtype],
    ):
        self.points = [
            p1.coords.unsafe_ptr()[0],
            p1.coords.unsafe_ptr()[1],
            p2.coords.unsafe_ptr()[0],
            p2.coords.unsafe_ptr()[1],
            p3.coords.unsafe_ptr()[0],
            p3.coords.unsafe_ptr()[1],
        ]


def make_tri_quad[
    dtype: DType, dims: Int = 2, winding: Int = CW
](p1: Point[dtype], p2: Point[dtype], thickness: Float32) -> Tuple[
    Triangle[dtype, dims, winding], Triangle[dtype, dims, winding]
]:
    """Takes 2 points, and a with and creates a TriQuad centered along the
    line.
    """
    comptime assert dtype.is_floating_point()
    var thickness_radius = thickness / 2.0

    var dxy = p2.load[2]() - p1.load[2]()
    var length = sqrt((dxy**2.0).reduce_add())
    if length == 0:
        length = 1.0

    # var denom = h.load[2]().reduce_max() - h.load[2]().reduce_min()
    # if denom == 0:
    #     denom = 1.0
    # h = (h - h.load[2]().reduce_min()) / denom

    var nx = dxy[1] / length
    var ny = -dxy[0] / length

    print(
        "length: ",
        length,
        "dxy: ",
        dxy,
        "nx: ",
        nx,
        "ny: ",
        ny,
        "p1: ",
        p1.load[2](),
        "p2: ",
        p2.load[2](),
    )

    var h_perp = Point[dtype](nx, ny)
    # print("h: ", h, "h_perp: ", h_perp)

    var t1_a = p1 + h_perp * Scalar[dtype](thickness_radius)
    var t1_b = p1 - h_perp * Scalar[dtype](thickness_radius)
    var t2_a = p2 + h_perp * Scalar[dtype](thickness_radius)
    var t2_b = p2 - h_perp * Scalar[dtype](thickness_radius)

    # print("t1_a: ", t1_a, "t1_b: ", t1_b, "t2_a: ", t2_a, "t2_b: ", t2_b)

    var t1 = Triangle[dtype, dims, winding](t1_a, t2_a, t1_b)
    var t2 = Triangle[dtype, dims, winding](t2_b, t1_b, t2_a)

    return (t1, t2)

    # var slope = (p2 - p1)
    # # var dot = (p1 * p2).load().reduce_add()
    # # var left = - (p2 / p1)

    # var left = slope * Point[Self.dtype](1.0, -1.0)
    # # var right = SIMD[Self.dtype, 2](
    # #     Scalar[Self.dtype](-slope.load()[0]),
    # #     Scalar[Self.dtype](slope.load()[1])
    # # )
    # print("left: ", left, 'p1: ', p1, 'p2: ', p2)
    # p1 1,1
    # p2 2,2
    # slope is 1,1

    # p1 1,1
    # p2 1,2
    # slope 0,1

    # var delta = (p2 - p1).cast[Float32.dtype]()
    # var angle = tan(delta.coords)
    # var a = Float32(thickness)
    # var b = Float32(thickness + 1)
    # var a:Float64 = Float64(p1.cast[Float32.dtype]().coords[0].copy() + 20)
    # var b:Float64 = Float64(p2.cast[Float32.dtype]().coords[0].copy() + 20)

    # var angle = atan2(p1.load(), p2.load()).reduce_add() / Point[Self.dtype].dim
    # var angle = atan2(p1.coords.load(), p2.coords.load())
    # var angle = atan2(
    #     a,
    #     b
    # )
    # var angle = atan2(
    #     Float32(3.0),
    #     Float32(4.0)
    # )
    # print("angle: ", angle, 'delta: ', delta.coords)
    # var p11 = p1

    # self.points = InlineArray[Scalar[Self.dtype], 6 * Self.dims](uninitialized=True)


def tessellate_line[
    dtype: DType
](
    curves: List[QuadBezierCurve[dtype]], thickness: Float32, tolarence: Int = 1
) raises -> List[Triangle[Float64.dtype]]:
    """Draws a ribbon of `TriQuad`s along a line whose width is `thickness`."""
    comptime assert dtype.is_floating_point()
    var triangles = List[Triangle[Float64.dtype]]()
    var prev_point: Optional[Point[Float64.dtype]] = None
    # var point: Point[Float64.dtype]
    var points = List[Point[Float64.dtype]]()

    for curve in curves:
        decompose_bezier_curve(points, curve)

    for point in points:
        # TODO: Do we need to do and prev_point[] != point?
        if prev_point:
            var (t1, t2) = make_tri_quad(prev_point[], point, thickness)
            triangles.append(t1)
            triangles.append(t2)
            # break
        prev_point = point.copy()

    return triangles^


def draw_stroke(
    p0: Point[Float64.dtype],
    p1: Point[Float64.dtype],
    frame: UnsafePointer[Scalar[DType.uint8], MutAnyOrigin],
    row_stride: Int,
    channels: Int,
) -> None:
    """Draws a stroke between two points to a frame."""
    var h = p1 - p0
    var start_point = p0
    var denom = h.load().reduce_max() - h.load().reduce_min()
    if denom == 0:
        denom = 1.0
    var h_norm = h / denom
    var n_steps = abs(h.load()).reduce_max() / abs(h_norm.load()).reduce_max()
    # print(
    #     "(draw_stroke) start_point: ",
    #     start_point.load[2](),
    #     "end point: ",
    #     p1.load[2](),
    #     "h: ",
    #     h.load[2](),
    #     "denom: ",
    #     denom,
    #     "h_norm: ",
    #     h_norm.load[2](),
    #     "n_steps: ",
    #     n_steps,
    # )
    for _ in range(n_steps):
        var offset = Int(round(start_point.coords[1])) * row_stride + Int(
            round(start_point.coords[0])
        )
        # print("(draw_stroke) offset: ", offset)
        frame.store(val=255, offset=offset)
        start_point += h_norm
        # print("start_point: ", start_point, "p1: ", p1)


def draw_triangle_strokes(
    triangle: Triangle[Float64.dtype],
    frame: UnsafePointer[Scalar[DType.uint8], MutAnyOrigin],
    row_stride: Int,
    channels: Int,
) -> None:
    """Draws the strokes of a triangle to a frame."""
    var p1 = Point[Float64.dtype](triangle.points[0], triangle.points[1])
    var p2 = Point[Float64.dtype](triangle.points[2], triangle.points[3])
    var p3 = Point[Float64.dtype](triangle.points[4], triangle.points[5])

    draw_stroke(p1, p2, frame, row_stride, channels)
    draw_stroke(p2, p3, frame, row_stride, channels)
    draw_stroke(p3, p1, frame, row_stride, channels)


def draw_triangle_fill(
    triangle: Triangle[Float64.dtype],
    frame: UnsafePointer[Scalar[DType.uint8], MutAnyOrigin],
    row_stride: Int,
    channels: Int,
) -> None:
    """Draws the fill of a triangle to a frame."""
    var p1 = Point[Float64.dtype](triangle.points[0], triangle.points[1])
    var p2 = Point[Float64.dtype](triangle.points[2], triangle.points[3])
    var p3 = Point[Float64.dtype](triangle.points[4], triangle.points[5])

    var v1 = p2 - p1
    var v2 = p3 - p2
    var v3 = p1 - p3

    print("v1: ", v1.load[2](), "v2: ", v2.load[2](), "v3: ", v3.load[2]())

    # NOTE: We add the extra p3.coords[0] to get power of 2.
    # TODO: Should we use quads since those have 4 points / power of 2?
    var min_x = SIMD[Float64.dtype, 4](
        p1.coords[0], p2.coords[0], p3.coords[0], p3.coords[0]
    ).reduce_min()
    var max_x = SIMD[Float64.dtype, 4](
        p1.coords[0], p2.coords[0], p3.coords[0], p3.coords[0]
    ).reduce_max()
    var min_y = SIMD[Float64.dtype, 4](
        p1.coords[1], p2.coords[1], p3.coords[1], p3.coords[1]
    ).reduce_min()
    var max_y = SIMD[Float64.dtype, 4](
        p1.coords[1], p2.coords[1], p3.coords[1], p3.coords[1]
    ).reduce_max()

    var imin_x = Int(round(min_x))
    var imax_x = Int(round(max_x))
    var imin_y = Int(round(min_y))
    var imax_y = Int(round(max_y))

    def is_point_in_triangle(
        p: Point[Float64.dtype],
        v: Point[Float64.dtype],
        p1: Point[Float64.dtype],
    ) -> Float64:
        var i_j = (v.load[2]()).reversed() * SIMD[Float64.dtype, 2](1.0, -1.0)
        var c = (i_j * p1.load[2]()).reduce_add() * -1.0
        return (i_j * p.load[2]()).reduce_add() + c

    for x in range(imin_x, imax_x + 1):
        for y in range(imin_y, imax_y + 1):
            var p = Point[Float64.dtype](Float64(x), Float64(y))

            var dot1 = is_point_in_triangle(p, v1, p1)
            var dot2 = is_point_in_triangle(p, v2, p2)
            var dot3 = is_point_in_triangle(p, v3, p3)
            if dot1 < 0.0 and dot2 < 0.0 and dot3 < 0.0:
                frame.store(val=255, offset=y * row_stride + x)
