# TODO: We might need to parameterize this to either 2 or 4 dimensions if we continue
# to use SIMD.
struct Point[dtype: DType = DType.float32](
    Copyable, Equatable, Movable, TrivialRegisterPassable, Writable
):
    comptime SIMDType = SIMD[Self.dtype, 4]
    var coords: Self.SIMDType

    def __init__(
        out self,
        x: Scalar[Self.dtype],
        y: Scalar[Self.dtype],
        z: Scalar[Self.dtype],
    ):
        self.coords = Self.SIMDType(x, y, z, 1.0)

    def __init__(out self, x: Scalar[Self.dtype], y: Scalar[Self.dtype]):
        self.coords = Self.SIMDType(
            x, y, Scalar[Self.dtype](1.0), Scalar[Self.dtype](1.0)
        )

    def __init__(out self, simd: Self.SIMDType):
        self.coords = simd

    def __sub__(self, other: Self) -> Self:
        return Self(self.coords - other.coords)

    def __truediv__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.coords / other)

    def __add__(self, other: Self) -> Self:
        return Self(self.coords + other.coords)

    def __mul__(self, other: Self) -> Self:
        return Self(self.coords * other.coords)

    def __mul__(self, other: Scalar[Self.dtype]) -> Self:
        return Self(self.coords * other)


struct QuadBezierCurve[dtype: DType = DType.float32](
    Copyable, ImplicitlyCopyable, Writable
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
        self.points = [anchor1, control1, control2, anchor2]

    def __init__(out self, anchor1: Self.Point, anchor2: Self.Point):
        var mag = anchor2 - anchor1
        var control1 = anchor1 + mag / 3.0
        var control2 = anchor2 - mag / 3.0
        self.points = [anchor1, control1, control2, anchor2]

    def __init__(out self, var points: InlineArray[Self.Point, Self.size]):
        self.points = points


def farin_rational_de_casteljau[
    dtype: DType, //
](quad_bezier_curve: QuadBezierCurve[dtype], t: Float32) -> Point[dtype]:
    """Calculates the point along a Bezier Curve.

    See: https://en.wikipedia.org/wiki/De_Casteljau's_algorithm
    See: https://drna.padovauniversitypress.it/system/files/papers/DRNA-2024-3-09.pdf
    """
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

    return (QuadBezierCurve(left), QuadBezierCurve(right))


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
            p_i_n[i] = p_i_n[size - 1]
        return QuadBezierCurve(p_i_n)
    if b == 0:
        comptime for i in range(size):
            p_i_n[i] = p_i_n[0]
        return QuadBezierCurve(p_i_n)
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


def interpolate(
    start: Float32,
    end: Float32,
    alpha: Float32,
) -> Float32:
    """Linearly interpolates between two values ``start`` and ``end``.

    See: https://github.com/ManimCommunity/manim/blob/21cf9998cc7ad34cdc5cb2fae09aa500d88d86c2/manim/utils/bezier.py#L1032
    """
    return (1 - alpha) * start + alpha * end
