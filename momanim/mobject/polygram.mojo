from momanim.typing import Vector3D
import numojo as nm
from std.math import sqrt


comptime draw_fn = fn(delta: Float32) -> Point


struct Point(Movable, TrivialRegisterPassable, Writable):
    comptime width = 3
    comptime dtype = DType.float32

    var point: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin]

    fn __init__(
        out self,
        x: Scalar[Self.dtype],
        y: Scalar[Self.dtype],
        z: Scalar[Self.dtype],
    ):
        self.point = alloc[Scalar[Self.dtype]](3)
        self.point.store(SIMD[Self.dtype, Self.width](x, y, z))

    fn __init__(out self, x: Scalar[Self.dtype], y: Scalar[Self.dtype]):
        self.point = alloc[Scalar[Self.dtype]](3)
        self.point[0] = x
        self.point[1] = y
        self.point[2] = 1.0

    @implicit
    fn __init__(
        out self,
        *elems: Scalar[Self.dtype],
        __list_literal__: Tuple[] = Tuple(),
    ) raises:
        self.point = alloc[Scalar[Self.dtype]](3)
        if len(elems) == 2:
            self.point[0] = elems[0]
            self.point[1] = elems[1]
            self.point[2] = 1.0
        elif len(elems) == 3:
            self.point[0] = elems[0]
            self.point[1] = elems[1]
            self.point[2] = elems[2]
        else:
            # TODO: Not a fan of this. This should be a compile time error.
            # however we can't know the number of elems at compile time.
            raise Error(
                "Invalid number of elements in the SIMD variadic constructor"
            )

    fn __init__(out self, point: SIMD[Self.dtype, Self.width]):
        self.point = alloc[Scalar[Self.dtype]](3)
        self.point.store(point)

    fn load(self) -> SIMD[Self.dtype, Self.width]:
        return self.point.load[Self.width]()

    fn __add__(self, other: Point) -> Point:
        return Point(self.load() + other.load())

    fn __sub__(self, other: Point) -> Point:
        return Point(self.load() - other.load())

    fn __mul__(self, other: Point) -> Point:
        return Point(self.load() * other.load())

    fn __truediv__(self, other: Point) -> Point:
        return Point(self.load() / other.load())

    fn __matmul__(self, other: Point) -> Scalar[Self.dtype]:
        return (self * other).load().reduce_add()

    fn __pow__(self, other: Int) -> Point:
        return Point(self.load() ** other)

    fn hypot(self, other: Point) -> Scalar[Self.dtype]:
        """Calculates the Euclidean distance between two points.

        See: https://en.wikipedia.org/wiki/Euclidean_distance
        """
        var diff = self - other
        return sqrt((diff**2).load().reduce_add())


struct Vector(Copyable, ImplicitlyCopyable, Movable, Writable):
    comptime width = Point.width * 2
    comptime dtype = DType.float32

    var vec: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin]

    fn __init__(out self, p0: Point, p1: Point):
        self.vec = alloc[Scalar[Self.dtype]](Self.width)
        self.vec.store(p0.load().join(p1.load()))

    fn __init__(out self, vec: SIMD[Self.dtype, Self.width]):
        self.vec = alloc[Scalar[Self.dtype]](Self.width)
        self.vec.store(vec)

    fn load(self) -> SIMD[Self.dtype, Self.width]:
        return self.vec.load[Self.width]()

    fn p0(self) -> Point:
        return Point(self.load().slice[Point.width, offset=0]())

    fn p1(self) -> Point:
        return Point(self.load().slice[Point.width, offset=Point.width]())

    fn hypot(self) -> Scalar[Self.dtype]:
        return self.p0().hypot(self.p1())

    fn join(self, other: Vector) -> SIMD[Self.dtype, Self.width * 2]:
        "Returns a joined SIMD vector of the two vectors."
        return self.load().join(other.load())


struct Square:
    comptime width = Vector.width * 4
    comptime dtype = DType.float32

    var vertices: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin]
    # var alphas: nm.NDArray[DType.float32]
    # var colors: nm.NDArray[DType.uint8]
    var color_fill: SIMD[DType.uint8, 4]

    def __init__(out self, *, color_fill: SIMD[DType.uint8, 4]) raises:
        self.vertices = alloc[Scalar[Self.dtype]](Self.width)
        var v0 = Vector([-1.0, -1.0], [1.0, -1.0])
        var v1 = Vector(v0.p1(), [1.0, 1.0])
        var v2 = Vector(v1.p1(), [-1.0, 1.0])
        var v3 = Vector(v2.p1(), [-1.0, -1.0])
        for i, v in enumerate([v0, v1, v2, v3]):
            self.vertices.store(val=v.load(), offset=Vector.width * i)
        # self.vertices.store((v0.join(v1)).join(v2.join(v3)))
        self.color_fill = color_fill

    def __init__(
        out self,
        v0: Vector,
        v1: Vector,
        v2: Vector,
        v3: Vector,
        *,
        color_fill: SIMD[DType.uint8, 4],
    ) raises:
        self.vertices = alloc[Scalar[Self.dtype]](Self.width)
        for i, v in enumerate([v0, v1, v2, v3]):
            self.vertices.store(val=v.load(), offset=Vector.width * i)
        self.color_fill = color_fill

    fn load(self) -> SIMD[Self.dtype, Self.width]:
        return self.vertices.load[Self.width]()

    def v0(self) -> Vector:
        return Vector(self.load().slice[Vector.width, offset=0]())

    def v1(self) -> Vector:
        return Vector(self.load().slice[Vector.width, offset=Vector.width]())

    def v2(self) -> Vector:
        return Vector(
            self.load().slice[Vector.width, offset=Vector.width * 2]()
        )

    def v3(self) -> Vector:
        return Vector(
            self.load().slice[Vector.width, offset=Vector.width * 3]()
        )

    def compile_bezier(self):
        pass

    # def flip(self, direction: Vector3D) -> None:
    #     pass

    # def rotate(self, angle: Float32) -> None:
    #     pass
