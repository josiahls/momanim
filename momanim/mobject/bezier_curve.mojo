# TODO: We might need to parameterize this to either 2 or 4 dimensions if we continue
# to use SIMD.
struct Point[dtype: DType = DType.float32](
    Copyable, Equatable, ImplicitlyCopyable, Movable, Writable
):
    comptime dim: Int = 4
    var coords: InlineArray[Scalar[Self.dtype], Self.dim]

    def __init__(
        out self,
        x: Scalar[Self.dtype],
        y: Scalar[Self.dtype],
        z: Scalar[Self.dtype],
    ):
        self.coords = [x, y, z, 1.0]

    def __init__(out self, x: Scalar[Self.dtype], y: Scalar[Self.dtype]):
        self.coords = [x, y, Scalar[Self.dtype](1.0), Scalar[Self.dtype](1.0)]

    def cast[target_dtype: DType](self) -> Point[target_dtype]:
        return Point(
            Scalar[target_dtype](self.coords[0]),
            Scalar[target_dtype](self.coords[1]),
            Scalar[target_dtype](self.coords[2]),
        )

    def __init__(out self, coords: InlineArray[Scalar[Self.dtype], Self.dim]):
        self.coords = coords.copy()

    def __init__(out self, simd: SIMD[Self.dtype, 2]):
        self.coords = [
            simd[0],
            simd[1],
            Scalar[Self.dtype](1.0),
            Scalar[Self.dtype](1.0),
        ]

    def __init__(out self, simd: SIMD[Self.dtype, Self.dim]):
        # TODO: Need to handle this case also.
        self.coords = [simd[0], simd[1], simd[2], simd[3]]

    def load[width: Int = Self.dim](self) -> SIMD[Self.dtype, width]:
        return self.coords.unsafe_ptr().load[width]()

    def __sub__(self, other: Self) -> Self:
        return Self(self.load() - other.load())

    def __sub__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.load() - other)

    def __truediv__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.load() / other)

    def __add__(self, other: Self) -> Self:
        return Self(self.load() + other.load())

    def __add__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.load() + other)

    def __mul__(self, other: Self) -> Self:
        return Self(self.load() * other.load())

    def __mul__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.load() * other)

    def __mul__(self, other: SIMD[Self.dtype, Self.dim]) -> Self:
        return Self(self.load() * other)

    def __imul__(mut self, other: Self):
        self.coords.unsafe_ptr().store(self.load() * other.load())

    def __imul__(mut self, other: Scalar[Self.dtype]):
        self.coords.unsafe_ptr().store(self.load() * other)

    def __iadd__(mut self, other: SIMD[Self.dtype, Self.dim]):
        var ptr = self.coords.unsafe_ptr()
        # print("\tpoint before: ", ptr.load[Self.dim](), ' + ', other)
        ptr.store(offset=0, val=self.load() + other)
        # print("\tpoint after: ", ptr.load[Self.dim]())

    def __iadd__(mut self, other: Self):
        self.coords.unsafe_ptr().store(self.load() + other.load())


struct QuadBezierCurve[dtype: DType = DType.float32](
    Copyable, ImplicitlyCopyable, Movable, Writable
):
    """A quadratic bezier curve defined by a start point, 2 control points,
    and an end point.
    """

    comptime size = 4
    comptime Point = Point[Self.dtype]

    var points: InlineArray[Self.Point, Self.size]

    def __init__(
        out self,
        anchor1: Self.Point,
        control1: Self.Point,
        control2: Self.Point,
        anchor2: Self.Point,
    ):
        self.points = [
            anchor1.copy(),
            control1.copy(),
            control2.copy(),
            anchor2.copy(),
        ]

    def __init__(out self, anchor1: Self.Point, anchor2: Self.Point):
        var mag = anchor2 - anchor1
        var control1 = anchor1 + mag / 3.0
        var control2 = anchor2 - mag / 3.0
        self.points = [anchor1.copy(), control1^, control2^, anchor2.copy()]

    def __init__(out self, var points: InlineArray[Self.Point, Self.size]):
        self.points = points^

    def __imul__(mut self, other: Scalar[Self.dtype]):
        for ref point in self.points:
            point *= other

    def __iadd__(mut self, other: SIMD[Self.dtype, Point.dim]):
        for ref point in self.points:
            point += other

    def min_x(self) -> Scalar[Self.dtype]:
        return SIMD[Self.dtype, 4](
            self.points[0].coords[0],
            self.points[1].coords[0],
            self.points[2].coords[0],
            self.points[3].coords[0],
        ).reduce_min()

    def min_y(self) -> Scalar[Self.dtype]:
        return SIMD[Self.dtype, 4](
            self.points[0].coords[1],
            self.points[1].coords[1],
            self.points[2].coords[1],
            self.points[3].coords[1],
        ).reduce_min()

    def max_x(self) -> Scalar[Self.dtype]:
        return SIMD[Self.dtype, 4](
            self.points[0].coords[0],
            self.points[1].coords[0],
            self.points[2].coords[0],
            self.points[3].coords[0],
        ).reduce_max()

    def max_y(self) -> Scalar[Self.dtype]:
        return SIMD[Self.dtype, 4](
            self.points[0].coords[1],
            self.points[1].coords[1],
            self.points[2].coords[1],
            self.points[3].coords[1],
        ).reduce_max()


def farin_rational_de_casteljau[
    dtype: DType, //
](quad_bezier_curve: QuadBezierCurve[dtype], t: Float32) -> Point[dtype]:
    """Calculates the point along a Bezier Curve.

    See: https://en.wikipedia.org/wiki/De_Casteljau's_algorithm
    See: https://drna.padovauniversitypress.it/system/files/papers/DRNA-2024-3-09.pdf
    """
    if t == 0:
        return quad_bezier_curve.points[0]
    if t == 1:
        return quad_bezier_curve.points[3]
    # TODO: Is a copy the only way to handle this?
    var p_i_n = quad_bezier_curve.points.copy()
    # size = number of control points = n + 1 (degree n).
    comptime n = QuadBezierCurve.size - 1

    # TODO: Note the Farin part of the  algorithm includes `weights`. We don't
    # add that for now, will want to probably later.

    # De Casteljau: for each r = 1,…,n, compute P_i^r for i = 0,…,n−r (not 0,…,n).
    comptime for r in range(1, QuadBezierCurve.size):
        comptime for i in range(QuadBezierCurve.size - r):
            p_i_n[i] = p_i_n[i] * (1 - Scalar[dtype](t)) + p_i_n[
                i + 1
            ] * Scalar[dtype](t)

    return p_i_n[0]  # P_0^n


def farin_rational_de_casteljau_split[
    dtype: DType, //
](quad_bezier_curve: QuadBezierCurve[dtype], t: Float32) -> Tuple[
    QuadBezierCurve[dtype], QuadBezierCurve[dtype]
]:
    """Split at `t`: first curve is [0, t], second is [t, 1] in parameter.

    The algorithm ensures that stitched back together the curves  are continuous.

    De Casteljau’s left polygon is already P0 → C (increasing t). The right
    polygon is collected as Pn, …, C (toward the split), so for a forward
    QuadBezierCurve(C, …, Pn) use indices …, 1, 0 — not a swapped tuple.

    See: https://en.wikipedia.org/wiki/De_Casteljau's_algorithm
    See: https://drna.padovauniversitypress.it/system/files/papers/DRNA-2024-3-09.pdf
    """
    comptime size = QuadBezierCurve.size
    comptime output_dtype = Scalar[dtype]
    var left = InlineArray[Point[dtype], size](uninitialized=True)
    var right = InlineArray[Point[dtype], size](uninitialized=True)
    # TODO: We should just change DType to Floatable to avoid all of these casts.
    var split_index = 0
    # TODO: Is a copy the only way to handle this?
    var p_i_n = quad_bezier_curve.points.copy()
    # size = number of control points = n + 1 (degree n).
    # TODO: Could be use:
    # https://docs.modular.com/mojo/std/math/polynomial/polynomial_evaluate/ ?
    comptime for r in range(1, size):
        comptime for i in range(size - r):
            if i == 0:
                left[split_index] = p_i_n[i]
            if i == size - r - 1:
                right[size - split_index - 1] = p_i_n[i + 1]
            p_i_n[i] = p_i_n[i] * (1 - output_dtype(t)) + p_i_n[
                i + 1
            ] * output_dtype(t)
        split_index += 1

    left[split_index] = p_i_n[0]
    right[size - split_index - 1] = p_i_n[0]

    return (QuadBezierCurve(left^), QuadBezierCurve(right^))


def control_point_loss[dtype: DType](curve: QuadBezierCurve[dtype]) -> Float64:
    ref ctrl_p1 = curve.points[1]
    ref ctrl_p2 = curve.points[2]
    var sub_curve = farin_rational_de_casteljau_between(curve, 0.25, 0.75)
    ref p0 = sub_curve.points[0]
    ref p3 = sub_curve.points[3]
    var delta_pt = (ctrl_p1 - p0 + ctrl_p2 - p3) / 2
    return Float64(abs(delta_pt.coords.unsafe_ptr().load().reduce_add())) / 3.0


# def control_point_loss[dtype:DType](curve: QuadBezierCurve[dtype]) -> Float64:
#     ref ctrl_p1 = curve.points[1]
#     ref ctrl_p2 = curve.points[2]
#     var sub_curve = farin_rational_de_casteljau_between(curve, 0.25, 0.75)
#     ref p0 = sub_curve.points[0]
#     ref p3 = sub_curve.points[3]
#     var delta_pt = (ctrl_p1 - p0 + ctrl_p2 - p3) / 2
#     return Float64(abs(delta_pt.coords.unsafe_ptr().load().reduce_add())) / 3.0


def decompose_bezier_curve[
    point_dtype: DType, dtype: DType, //
](
    mut points: List[Point[point_dtype]],
    quad_bezier_curve: QuadBezierCurve[dtype],
    tolerance: Float64 = 0.1,
):
    """Adaptively and recurvely split a list of curves into smller segments.

    It will flatten curves until both control points are within `tolerance` of
    the actual calculated curve.

    See:
    - https://agg.sourceforge.net/antigrain.com/research/adaptive_bezier/#toc0003
    """
    var loss = control_point_loss(quad_bezier_curve)

    # TODO: Note that we should also consider angle loss.
    # https://agg.sourceforge.net/antigrain.com/research/adaptive_bezier/#toc0003
    # print('control point loss: ', loss)
    if loss <= tolerance:
        for point in quad_bezier_curve.points:
            points.append(point.cast[point_dtype]())
    else:
        var left, right = farin_rational_de_casteljau_split(
            quad_bezier_curve, 0.5
        )
        decompose_bezier_curve(points, left, tolerance)
        decompose_bezier_curve(points, right, tolerance)


def farin_rational_de_casteljau_between[
    dtype: DType, //
](
    quad_bezier_curve: QuadBezierCurve[dtype],
    a: Float32,
    b: Float32,
) -> QuadBezierCurve[dtype]:
    """Subcurve with the same geometry as the original on parameter interval [a, b].

    Same idea as Manim ``partial_bezier_points``: split at ``a`` and keep the right
    piece (maps [a, 1] → [0, 1]), then split that at u = (b - a) / (1 - a) and keep
    the left piece (maps [a, b] → [0, 1]).
    """
    comptime size = quad_bezier_curve.size
    var p_i_n = quad_bezier_curve.points.copy()

    if a == 1:
        comptime for i in range(size):
            p_i_n[i] = p_i_n[size - 1].copy()
        return QuadBezierCurve(p_i_n^)
    if b == 0:
        comptime for i in range(size):
            p_i_n[i] = p_i_n[0].copy()
        return QuadBezierCurve(p_i_n^)
    if a == 0 and b == 1:
        return quad_bezier_curve

    var tail = quad_bezier_curve
    if a != 0:
        tail = farin_rational_de_casteljau_split(quad_bezier_curve, a)[1]
    var u = (b - a) / (1 - a)
    return farin_rational_de_casteljau_split(tail, u)[0]


def integer_interpolate(
    start: Float32,
    end: Float32,
    alpha: Float32,
) -> Tuple[Int, Float32]:
    """This is a variant of interpolate that returns an integer and the residual.

    Parameters
    ----------
    start
        The start of the range
    end
        The end of the range
    alpha
        a float between 0 and 1.

    Returns
    -------
    tuple[int, float]
        This returns an integer between start and end (inclusive) representing
        appropriate interpolation between them, along with a
        "residue" representing a new proportion between the
        returned integer and the next one of the
        list.

    See: https://github.com/ManimCommunity/manim/blob/21cf9998cc7ad34cdc5cb2fae09aa500d88d86c2/manim/utils/bezier.py#L1067
    """
    if alpha >= 1:
        return (Int(end - 1), 1.0)
    if alpha <= 0:
        return (Int(start), 0)
    value = Int(interpolate(start, end, alpha))
    residue = ((end - start) * alpha) % 1
    return (value, residue)


def interpolate[
    T: DType, width: Int
](
    start: SIMD[T, width],
    end: SIMD[T, width],
    alpha: Scalar[T],
) -> SIMD[
    T, width
]:
    """Linearly interpolates between two values ``start`` and ``end``.

    See: https://github.com/ManimCommunity/manim/blob/21cf9998cc7ad34cdc5cb2fae09aa500d88d86c2/manim/utils/bezier.py#L1032
    """
    return (1 - alpha) * start + alpha * end
