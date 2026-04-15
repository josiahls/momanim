"""Simple non-beazier curve geometry pimitives.

All pimitives are `size ** 2` for SIMD compat.
"""


@fieldwise_init
struct Point2d(Copyable, Writable):
    var x: Float32
    var y: Float32

    def __init__(out self, simd: SIMD[Float32.dtype, 2]):
        self.x = simd[0]
        self.y = simd[1]

    def simd(self) -> SIMD[Float32.dtype, 2]:
        return SIMD[Float32.dtype, 2](self.x, self.y)

    def reversed(self) -> Self:
        return {self.simd().reversed()}

    def __sub__(self, other: Self) -> Self:
        return {self.simd() - other.simd()}

    def __mul__(self, other: Self) -> Self:
        return {self.simd() * other.simd()}

    def sum(self) -> Float32:
        return self.simd().reduce_add()


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


struct HalfPlane2d(Copyable, Writable):
    var i: Float32
    var j: Float32
    var c: Float32

    def __init__(out self, v: Vector2d):
        """Calculates a halfplane (hyper plane) from a 2d vector.

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
        var ij = mag.reversed() * Point2d(1.0, -1.0)
        self.c = (ij * v.p1).sum() * -1.0
        self.i = ij.simd()[0]
        self.j = ij.simd()[1]

    def ij(self) -> SIMD[Float32.dtype, 2]:
        return SIMD[Float32.dtype, 2](self.i, self.j)

    def point_relative_to_plane(self, p: Point2d) -> Float32:
        return (self.ij() * p.simd()).reduce_add() + self.c


@fieldwise_init
struct Vector3d(Copyable, Writable):
    var p1: Point3d
    var p2: Point3d


@fieldwise_init
struct Plane2d(Copyable, Writable):
    var v1: Vector2d
    var v2: Vector2d
    var normal: Vector2d


@fieldwise_init
struct Plane3d(Copyable, Writable):
    var v1: Vector3d
    var v2: Vector3d
    var normal: Vector3d
