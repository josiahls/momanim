"""Simple non-beazier curve geometry pimitives.

All pimitives are `size ** 2` for SIMD compat.
"""
from std.math import Floorable, floor, hypot
from std.memory import memset_zero
from momanim.pix_forge.fixed_dtype import FixedInt


@fieldwise_init
struct Point2d(Comparable, Copyable, Floorable, Writable):
    var x: Float32
    var y: Float32

    def __init__(out self, simd: SIMD[Float32.dtype, 2]):
        self.x = simd[0]
        self.y = simd[1]

    def __init__(out self, *, cast_x: Float64, cast_y: Float64):
        # TODO: We probably don't want to support this implcitly.
        self.x = Float32(cast_x)
        self.y = Float32(cast_y)

    def simd(self) -> SIMD[Float32.dtype, 2]:
        return SIMD[Float32.dtype, 2](self.x, self.y)

    def reversed(self) -> Self:
        return {self.simd().reversed()}

    def __sub__(self, other: Self) -> Self:
        return {self.simd() - other.simd()}

    def __mul__(self, other: Self) -> Self:
        return {self.simd() * other.simd()}

    def __mul__(self, other: Float32) -> Self:
        return {self.simd() * other}

    def sum(self) -> Float32:
        return self.simd().reduce_add()

    def __floor__(self) -> Self:
        return {floor(self.simd())}

    def __lt__(self, other: Self) -> Bool:
        return self.simd().reduce_max() < other.simd().reduce_min()

    def normalize_slope_(mut self) -> Float32:
        """An inplace op that normalizes the point to a unit coordinate.

        Returns:
            The resulting unit magnitude.
        """
        if self.x == 0.0 and self.y == 0.0:
            return 0

        if self.x == 0.0:
            if self.y > 0.0:
                self.y = 1.0
                return self.y
            else:
                self.y = -1.0
                return self.y
        elif self.y == 0.0:
            if self.x > 0.0:
                self.x = 1.0
                return self.x
            else:
                self.x = -1.0
                return self.x
        else:
            var mag = hypot(self.x, self.y)
            self.x /= mag
            self.y /= mag
            return mag

    def round[round_places: Int = 0](self) -> Self:
        var x = self.x
        var y = self.y
        if round_places > 0:
            x = round(x, round_places)
            y = round(y, round_places)
        # TODO: This is bad, need to reconfigure the casting to not truncate.
        return {x, y}


struct Point3d(Copyable, Writable):
    var x: Float32
    var y: Float32
    var z: Float32
    var homogenous_coordinate: Float32

    def __init__(
        out self,
        x: Float32,
        y: Float32,
        z: Float32,
        homogenous_coordinate: Float32 = 1.0,
    ):
        self.x = x
        self.y = y
        self.z = z
        self.homogenous_coordinate = homogenous_coordinate


@fieldwise_init
struct Vector2d(Copyable, Equatable, Writable):
    var p1: Point2d
    var p2: Point2d

    def magnitude(self) -> Point2d:
        return self.p2 - self.p1

    def swap(self) -> Self:
        return {self.p2.copy(), self.p1.copy()}

    def min_y(self) -> Float32:
        return min(self.p1.y, self.p2.y)

    def max_y(self) -> Float32:
        return max(self.p1.y, self.p2.y)

    def translate(mut self, dx: Float32, dy: Float32):
        self.p1.x += dx
        self.p2.x += dx
        self.p1.y += dy
        self.p2.y += dy

    def translate(mut self, pt: Point2d):
        self.p1.x += pt.x
        self.p2.x += pt.x
        self.p1.y += pt.y
        self.p2.y += pt.y

    def flat(self) -> InlineArray[Float32, 4]:
        return [self.p1.x, self.p1.y, self.p2.x, self.p2.y]

    def round[round_places: Int = 0](self) -> Self:
        return {self.p1.round[round_places](), self.p2.round[round_places]()}


struct HalfPlane2d(Copyable, Writable):
    comptime CCW: Bool = True
    var ij: Point2d  # NOTE: Should this actually be a 2d point?
    var c: Float32

    def __init__(out self, v: Vector2d):
        """Calculates a halfplane (hyper plane) from a 2d vector.

        Reference: https://mathworld.wolfram.com/CrossProduct.html

        Given `v`: (0,4) -> (8,12)
        and Given:
            `p1` is (0,4)
            `p` (from `point_relative_to_plane`): (5,8)

        Answer: Is (5,8) inside or outside (under or over) this half plane?

        ```
        edge = (8,12) - (0.4) = (8,8)

        n = edge * k = [
            [i, j, k]
            [8, 8, 0]
            [0, 0, 1]
        ]
        ```

        `n = i(8) - j(8) + k(0) = 8i - 8j` where:

        `a = 8` and `b = -8` and `p1 = (x,y) = x = 0` and `y = 4`

        Solve for the inequality. We use `p1` since we know it is on the plane
        to get `c`

        `ax + by + c <= 0`

        `8 * 0 - 8 * 4 = -c => 32 = c`

        Now that we know `c`, plug in p`

        `ax + by + c <= 0`

        `8 * 5 - 8 * 8 + 32 <= 0` -> -24 + 32 <= 0 -> 8 <= 0

        Since `8 <= 0`, we deterine the point is "outside or above" the line if
        the line is moving in a counter clockwise direction. We we had a square
        we could then do this for the other 3 lines to determine if any point
        is inside the square.
        """
        var mag = v.magnitude()
        # NOTE: Assumes this is CCW.
        self.ij = mag.reversed() * Point2d(1.0, -1.0)
        self.c = (self.ij * v.p1).sum() * -1.0

    def point_relative_to_plane(self, p: Point2d) -> Float32:
        return (self.ij * p).sum() + self.c

    def x_from_y(self, y: Float32) -> Float32:
        var b_div_a: Float32
        if self.ij.x == 0:  # I think this is dx == 0, so vertical.
            return self.c  # right? Do we need to involve self.c?
        else:
            b_div_a = -self.c - self.ij.y * y
            b_div_a /= self.ij.x
            return b_div_a

    def point_from_y(self, y: Float32) -> Point2d:
        return Point2d(self.x_from_y(y), y)


@fieldwise_init
struct Triangle2d(Copyable, Writable):
    """A 2d triable composed of 3 half planes.

    These half planes have the original vector, and the half plane for bounds
    checking.
    """

    var v1: HalfPlane2d
    var v2: HalfPlane2d
    var v3: HalfPlane2d

    def __init__(out self, var p1: Point2d, var p2: Point2d, var p3: Point2d):
        self.v1 = {Vector2d(p1.copy(), p2.copy())}
        self.v2 = {Vector2d(p2^, p3.copy())}
        self.v3 = {Vector2d(p3^, p1^)}

    def __contains__(self, p: Point2d) -> Bool:
        # TODO: Is there a better simd method here?

        # NOTE: Must be counter clockwise order!
        return (
            self.v1.point_relative_to_plane(p) <= 0.0
            and self.v2.point_relative_to_plane(p) <= 0.0
            and self.v3.point_relative_to_plane(p) <= 0.0
        )


@fieldwise_init
struct Trapezoid2d(Copyable, Writable):
    var t1: Triangle2d
    var t2: Triangle2d

    def __contains__(self, p: Point2d) -> Bool:
        return p in self.t1 or p in self.t2


@fieldwise_init
struct Vector3d(Copyable, Writable):
    var p1: Point3d
    var p2: Point3d


@fieldwise_init
struct FixedPoint2d(Copyable, Equatable, Movable, Writable):
    var x: FixedInt
    var y: FixedInt

    def __init__(out self, p: Point2d):
        self.x = FixedInt(from_float=p.x)
        self.y = FixedInt(from_float=p.y)

    def __sub__(self, other: Self) -> Self:
        return {self.x - other.x, self.y - other.y}

    def point_2d[round_places: Int = 0](self) -> Point2d:
        var x = Float64(self.x)
        var y = Float64(self.y)
        if round_places > 0:
            x = round(x, round_places)
            y = round(y, round_places)
        # TODO: This is bad, need to reconfigure the casting to not truncate.
        return Point2d(Float32(x), Float32(y))


# TODO: Rename to FixedPointeVector2d
@fieldwise_init
struct FixedPointEdge2d(Copyable, Equatable, Movable, Writable):
    var p0: FixedPoint2d
    var p1: FixedPoint2d

    def __init__(out self, p0: Point2d, p1: Point2d):
        self.p0 = FixedPoint2d(p0)
        self.p1 = FixedPoint2d(p1)

    def __init__(out self, x0: Float32, y0: Float32, x1: Float32, y1: Float32):
        self.p0 = FixedPoint2d(Point2d(x0, y0))
        self.p1 = FixedPoint2d(Point2d(x1, y1))

    def __init__(out self, edge: Vector2d):
        self.p0 = FixedPoint2d(edge.p1)
        self.p1 = FixedPoint2d(edge.p2)

    def magnitude(self) -> FixedPoint2d:
        return self.p1 - self.p0

    def swap(self) -> Self:
        return {self.p1.copy(), self.p0.copy()}

    def y_top(self) -> FixedInt:
        """Get the top most (lowest value) y."""
        return min(self.p0.y, self.p1.y)

    def y_bot(self) -> FixedInt:
        """Get the bottom most (highest value) y."""
        return max(self.p0.y, self.p1.y)

    def vector_2d[round_places: Int = 0](self) -> Vector2d:
        return Vector2d(
            self.p0.point_2d[round_places](), self.p1.point_2d[round_places]()
        )
