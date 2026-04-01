struct Point[dtype: DType = DType.float32](
    Copyable, Equatable, Movable, TrivialRegisterPassable, Writable
):
    var coords: SIMD[Self.dtype, 3]

    def __init__(
        out self,
        x: Scalar[Self.dtype],
        y: Scalar[Self.dtype],
        z: Scalar[Self.dtype],
    ):
        self.coords = SIMD[Self.dtype, 3](x, y, z)

    def __init__(out self, x: Scalar[Self.dtype], y: Scalar[Self.dtype]):
        self.coords = SIMD[Self.dtype, 3](x, y, 1.0)

    def __init__(out self, simd: SIMD[Self.dtype, 3]):
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


struct QuadBezierCurve[size: Int = 4, dtype: DType = DType.float32](Copyable):
    """A quadratic bezier curve defined by a start point, 2 control points,
    and an end point.
    """

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
    dtype: DType, size: Int, //
](quad_bezier_curve: QuadBezierCurve[size, dtype], t: Scalar[dtype]) -> Point[
    dtype
]:
    """Calculates the point along a Bezier Curve.

    See: https://en.wikipedia.org/wiki/De_Casteljau's_algorithm
    See: https://drna.padovauniversitypress.it/system/files/papers/DRNA-2024-3-09.pdf
    """
    # TODO: Is a copy the only way to handle this?
    var p_i_n = quad_bezier_curve.points.copy()
    # size = number of control points = n + 1 (degree n).
    comptime n = size - 1

    # TODO: Note the Farin part of the  algorithm includes `weights`. We don't
    # add that for now, will want to probably later.

    # De Casteljau: for each r = 1,…,n, compute P_i^r for i = 0,…,n−r (not 0,…,n).
    comptime for r in range(1, size):
        comptime for i in range(size - r):
            p_i_n[i] = p_i_n[i] * (1 - t) + p_i_n[i + 1] * t

    return p_i_n[0]  # P_0^n


def farin_rational_de_casteljau_split[
    dtype: DType, size: Int, //
](quad_bezier_curve: QuadBezierCurve[size, dtype], t: Scalar[dtype]) -> Tuple[
    QuadBezierCurve[size, dtype], QuadBezierCurve[size, dtype]
]:
    """Split at `t`: first curve is [0, t], second is [t, 1] in parameter.

    The algorithm ensures that stitched back together the curves  are continuous.

    De Casteljau’s left polygon is already P0 → C (increasing t). The right
    polygon is collected as Pn, …, C (toward the split), so for a forward
    QuadBezierCurve(C, …, Pn) use indices …, 1, 0 — not a swapped tuple.

    See: https://en.wikipedia.org/wiki/De_Casteljau's_algorithm
    See: https://drna.padovauniversitypress.it/system/files/papers/DRNA-2024-3-09.pdf
    """
    var left = InlineArray[Point[dtype], size](uninitialized=True)
    var right = InlineArray[Point[dtype], size](uninitialized=True)
    var split_index = 0
    # TODO: Is a copy the only way to handle this?
    var p_i_n = quad_bezier_curve.points.copy()
    # size = number of control points = n + 1 (degree n).
    comptime for r in range(1, size):
        comptime for i in range(size - r):
            if i == 0:
                left[split_index] = p_i_n[i]
            if i == size - r - 1:
                right[size - split_index - 1] = p_i_n[i + 1]
            p_i_n[i] = p_i_n[i] * (1 - t) + p_i_n[i + 1] * t
        split_index += 1

    left[split_index] = p_i_n[0]
    right[size - split_index - 1] = p_i_n[0]

    return (QuadBezierCurve(left), QuadBezierCurve(right))


def farin_rational_de_casteljau_between[
    dtype: DType, size: Int, //, _use_left: Bool = False
](
    quad_bezier_curve: QuadBezierCurve[size, dtype],
    a: Scalar[dtype],
    b: Scalar[dtype],
) -> QuadBezierCurve[size, dtype]:
    # TODO: Is a copy the only way to handle this?
    var p_i_n = quad_bezier_curve.points.copy()

    # TODO: We should be able to unify these funcitons tbh, and clean up
    # the parameterization.

    # Handle edge cases.
    if a == 1:
        comptime for i in range(size):
            p_i_n[i] = p_i_n[0]
        return QuadBezierCurve(p_i_n)
    if b == 0:
        comptime for i in range(size):
            p_i_n[i] = p_i_n[size - 1]
        return QuadBezierCurve(p_i_n)

    var out = InlineArray[Point[dtype], size](uninitialized=True)
    var t: Scalar[dtype] = a
    var split_index = 0
    # size = number of control points = n + 1 (degree n).
    comptime for r in range(1, size):
        comptime for i in range(size - r):
            comptime if _use_left:
                if i == 0:
                    out[split_index] = p_i_n[i]

            comptime if not _use_left:
                if i == size - r - 1:
                    out[size - split_index - 1] = p_i_n[i + 1]
            p_i_n[i] = p_i_n[i] * (1 - t) + p_i_n[i + 1] * t
        split_index += 1

    comptime if _use_left:
        out[split_index] = p_i_n[0]
    else:
        out[size - split_index - 1] = p_i_n[0]

    comptime if _use_left:
        return QuadBezierCurve(out)
    else:
        # var residue = 1 - a
        return farin_rational_de_casteljau_between[_use_left=True](
            quad_bezier_curve=QuadBezierCurve(out), a=(b - a) / (1 - a), b=1
        )
