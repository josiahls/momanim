"""Simple non-beazier curve geometry pimitives.

All pimitives are `size ** 2` for SIMD compat.
"""
from std.math import Floorable, floor, hypot
from std.memory import memset_zero
from momanim.rasterization.fixed_dtype import FixedInt


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
struct Vector2d(Copyable, Writable):
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


struct HalfPlane2d(Copyable, Writable):
    comptime CCW: Bool = True
    var v: Vector2d
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
        self.v = (
            v.copy()
        )  # TODO: Do we even need this? I'm not sure we need it.
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
struct MaskImage:
    var data: UnsafePointer[Scalar[DType.uint8], MutExternalOrigin]
    var height: Int
    var width: Int
    var linesize: Int

    def __init__(out self, width: Int, height: Int):
        self = Self(width, height, width)

    def __init__(out self, width: Int, height: Int, linesize: Int):
        var size = linesize * height
        self.data = alloc[Scalar[DType.uint8]](size)
        memset_zero(self.data, size)
        self.width = width
        self.height = height
        self.linesize = linesize


@fieldwise_init
struct FixedPoint2d(Copyable, Movable, Writable):
    var x: FixedInt
    var y: FixedInt

    def __init__(out self, p: Point2d):
        self.x = FixedInt(p.x)
        self.y = FixedInt(p.y)

    def __sub__(self, other: Self) -> Self:
        return {self.x - other.x, self.y - other.y}

    def real_to_string(self) -> String:
        return (
            "(" + String(Float64(self.x)) + ", " + String(Float64(self.y)) + ")"
        )


@fieldwise_init
struct FixedPointEdge2d(Copyable, Movable, Writable):
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


@fieldwise_init
struct FixedPointTrapezoid2d(Copyable, Movable, Writable):
    var l: FixedPointEdge2d
    var r: FixedPointEdge2d
    var top: FixedInt
    var bot: FixedInt

    def __init__(out self, a: Point2d, b: Point2d, c: Point2d, d: Point2d):
        """Creates a trapezoid from four points.

        Notes:
        - Assumes roughly the ordering:
        - Assumes point ordering is CCW.
        - Assumes the y's of each pair should match.

        `a` ----- `d`
         |         ^
         v         |
         `b` ----- `c`
        """
        # assert a.y == d.y, "a.y != d.y"
        # assert b.y == c.y, "b.y != c.y"
        self.l = FixedPointEdge2d(a, b)
        self.r = FixedPointEdge2d(c, d)
        self.top = FixedInt(a.y)  # We assert that a.y and d.y are the same.
        self.bot = FixedInt(c.y)  # We assert that b.y and c.y are the same.

    def __init__(out self, edge_0: Vector2d, edge_1: Vector2d):
        """
        Initializes a trapezoid from two edges.

        Parameters:
            edge_0: The first edge.
            edge_1: The second edge.
        """
        var top = min(edge_0.min_y(), edge_1.min_y())
        var bot = max(edge_0.max_y(), edge_1.max_y())
        self.top = FixedInt(top)
        self.bot = FixedInt(bot)
        self.l = FixedPointEdge2d(edge_0)
        self.r = FixedPointEdge2d(edge_1)

    @staticmethod
    def traps_from_edge(edge: Vector2d, thickness: Float32) -> List[Self]:
        var half_plane = HalfPlane2d(edge)
        var norm_slope = half_plane.ij.copy()
        var _ = norm_slope.normalize_slope_()
        print(half_plane)
        # Left / Right in CCW terms.
        var edge_l = edge.copy()
        var edge_r = edge.copy()
        var half_line_width = thickness / 2
        # var slope = edge.magnitude()
        # var mag = slope.normalize_slope_()
        # # TODO: Note cairo: third_party/cairo/src/cairo-path-stroke-traps.c
        # # line: 615: checks stroker->ctm_inverse. I don't understand this,
        # # so im skipping implimenting it.

        # # 90 degree rotation.
        # # NOTE: hangon, this is the normal no? I already have a HalfPlane object for this?
        # var dx = -slope.y * half_line_width
        # var dy = slope.x * half_line_width

        # # Left / Right in the CCW direction of the edge.
        edge_l.translate(norm_slope * half_line_width)
        edge_r.translate(norm_slope * half_line_width * -1.0)
        print("left", edge_l)
        print("right", edge_r)

        # TODO: check whather dy == 0. If so, then both edges are parallel and will start and end on the same y.

        # if not:
        # - trap 1: p1 p1.x1, max(p1.y1,p2.y1) p2:
        var traps = List[Self](capacity=3)
        Self.traps_from_points(
            traps,
            edge_l,
            edge_r,
        )
        return traps^

    @staticmethod
    def traps_from_points(
        mut traps: List[Self],
        edge_l: Vector2d,
        edge_r: Vector2d,
    ):
        """
        edge_l and edge_r are assumed to be left / right per CCW direction.
        The trapezoids must be drawn in a x scaline friendly way via horizontally
        slicing up the bounding rectangle created by edge_l and edge_r.
        """
        var slope_l = HalfPlane2d(edge_l)
        var slope_r = HalfPlane2d(edge_r)
        print("slope_l", slope_l)
        print("slope_r", slope_r)
        # TODO: change these to poiners, or make a pair struct.
        var points: List[Tuple[Point2d, HalfPlane2d]] = [
            # Point, and the opposite slope.
            Tuple(edge_l.p1.copy(), slope_r.copy()),
            Tuple(edge_l.p2.copy(), slope_r.copy()),
            Tuple(edge_r.p1.copy(), slope_l.copy()),
            Tuple(edge_r.p2.copy(), slope_l.copy()),
        ]

        def cmp_point(
            a: Tuple[Point2d, HalfPlane2d], b: Tuple[Point2d, HalfPlane2d]
        ) capturing -> Bool:
            return a[0].y < b[0].y

        # TODO: wondering if we can just do a fast path SIMD comparison.
        # we should be able to see whether the points are y sorted in one shot.
        sort[cmp_point](points[:])

        var missing_pt1 = Point2d(
            points[1][1].x_from_y(points[1][0].y), points[1][0].y
        )
        var missing_pt2 = Point2d(
            points[2][1].x_from_y(points[2][0].y), points[2][0].y
        )

        var t1: Self = {points[0][0], points[1][0], points[0][0], missing_pt1}
        var t2: Self = {points[1][0], missing_pt1, points[2][0], missing_pt2}
        var t3: Self = {points[2][0], points[3][0], points[3][0], missing_pt2}

        print(points)
        print(t1)
        print(t2)
        print(t3)
        traps.append(t1^)
        traps.append(t2^)
        traps.append(t3^)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Trapezoid2d:\n")
        var s = self.l.p0.real_to_string()
        var pt_len = len(s)
        var half_len = pt_len / 2
        writer.write(s, "-" * pt_len, self.r.p0.real_to_string(), "\n")
        writer.write(" " * half_len, "|", " " * pt_len * 2, "^\n")
        writer.write(" " * half_len, "v", " " * pt_len * 2, "|\n")
        var s2 = self.l.p1.real_to_string()
        var pt_half_len2 = max(half_len - len(s2) / 2, 0)
        writer.write(
            " " * pt_half_len2,
            s2,
            "-" * pt_len,
            self.r.p1.real_to_string(),
            "\n",
        )
