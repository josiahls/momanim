from momanim.typing import Vector3D
import numojo as nm
from std.math import sqrt
from momanim.utils.color import WHITE


# trait Drawable(Movable):
#     """A Drawable is a object that can produce a `Point` from a floating scalar.

#     Conforming types implement `__call__(self, delta: Float32) -> Point`.

#     Delta is expected to range in [0, 1]. 0 should be the start of the path,
#     and 1 should be the end of the path.
#     """
#     def __call__(self, delta: Float32) -> Point: ...

# @fieldwise_init
# struct PolygramDrawFn(Drawable):
#     # TODO: We should just make this a polygram draw function e.g.:
#     # number of vectors and unit intervals should be flexible.
#     var unit_intervals: InlineArray[Float32, 4]
#     var vectors: InlineArray[Vector, 4]
#     var total_length: Float32

#     def __call__(self, delta: Float32) -> Point:
#         assert delta >= 0, "Delta must be >= 0 not: {}".format(delta)
#         assert delta <= 1, "Delta must be <= 1 not: {}".format(delta)
#         # `unit_intervals[i]` is arc-length fraction for segment i; map global
#         # delta in [0, 1] to a parameter t in [0, 1] along that segment only.
#         var segment_start: Float32 = 0.0
#         comptime for i in range(4):
#             var interval = self.unit_intervals[i]
#             var segment_end = segment_start + interval
#             if delta <= segment_end:
#                 var v = self.vectors[i]
#                 var t = (delta - segment_start) / interval
#                 var mag = v.mag()
#                 return v.p0() + mag * t
#             segment_start = segment_end

#         return self.vectors[3].p1()


# struct Point(Equatable, Movable, TrivialRegisterPassable, Writable):
#     comptime width = 3
#     comptime dtype = DType.float32

#     var point: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin]

#     fn __init__(
#         out self,
#         x: Scalar[Self.dtype],
#         y: Scalar[Self.dtype],
#         z: Scalar[Self.dtype],
#     ):
#         self.point = alloc[Scalar[Self.dtype]](3)
#         self.point.store(SIMD[Self.dtype, Self.width](x, y, z))

#     fn __init__(out self, x: Scalar[Self.dtype], y: Scalar[Self.dtype]):
#         self.point = alloc[Scalar[Self.dtype]](3)
#         self.point[0] = x
#         self.point[1] = y
#         self.point[2] = 1.0

#     fn __init__(
#         out self,
#         elems: List[Scalar[Self.dtype]],
#         __list_literal__: Tuple[] = Tuple(),
#     ):
#         self.point = alloc[Scalar[Self.dtype]](3)
#         self.point.store(
#             SIMD[Self.dtype, Self.width](elems[0], elems[1], elems[2])
#         )

#     fn __init__(out self, point: SIMD[Self.dtype, Self.width]):
#         self.point = alloc[Scalar[Self.dtype]](3)
#         self.point.store(point)

#     def write_to(self, mut writer: Some[Writer]):
#         writer.write("Point(", self.x(), ", ", self.y(), ", ", self.z(), ")")

#     def write_repr_to(self, mut writer: Some[Writer]):
#         writer.write("Point(", self.x(), ", ", self.y(), ", ", self.z(), ")")

#     def x(self) -> Scalar[Self.dtype]:
#         return self.point[0]

#     def y(self) -> Scalar[Self.dtype]:
#         return self.point[1]

#     def z(self) -> Scalar[Self.dtype]:
#         return self.point[2]

#     def __eq__(self, other: Point) -> Bool:
#         return self.load() == other.load()

#     fn load(self) -> SIMD[Self.dtype, Self.width]:
#         return self.point.load[Self.width]()

#     fn __add__(self, other: Point) -> Point:
#         return Point(self.load() + other.load())

#     fn __sub__(self, other: Point) -> Point:
#         return Point(self.load() - other.load())

#     fn __mul__(self, other: Scalar[Self.dtype]) -> Point:
#         return Point(self.load() * other)

#     fn __mul__(self, other: Point) -> Point:
#         return Point(self.load() * other.load())

#     fn __truediv__(self, other: Point) -> Point:
#         return Point(self.load() / other.load())

#     fn __matmul__(self, other: Point) -> Scalar[Self.dtype]:
#         return (self * other).load().reduce_add()

#     fn __pow__(self, other: Int) -> Point:
#         return Point(self.load() ** other)

#     fn hypot(self, other: Point) -> Scalar[Self.dtype]:
#         """Calculates the Euclidean distance between two points.

#         See: https://en.wikipedia.org/wiki/Euclidean_distance
#         """
#         var diff = self - other
#         return sqrt((diff**2).load().reduce_add())


# struct Vector(Copyable, ImplicitlyCopyable, Movable, Writable):
#     comptime width = Point.width * 2
#     comptime dtype = DType.float32

#     var vec: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin]

#     fn __init__(out self, p0: Point, p1: Point):
#         self.vec = alloc[Scalar[Self.dtype]](Self.width)
#         self.vec.store(p0.load().join(p1.load()))

#     fn __init__(
#         out self, p0: List[Scalar[Self.dtype]], p1: List[Scalar[Self.dtype]]
#     ):
#         self.vec = alloc[Scalar[Self.dtype]](Self.width)
#         if len(p0) == 2 and len(p1) == 2:
#             self.vec.store(
#                 SIMD[Self.dtype, Self.width](
#                     p0[0], p0[1], 1.0, p1[0], p1[1], 1.0
#                 )
#             )
#         elif len(p0) == 3 and len(p1) == 3:
#             self.vec.store(
#                 SIMD[Self.dtype, Self.width](
#                     p0[0], p0[1], p0[2], p1[0], p1[1], p1[2]
#                 )
#             )
#         else:
#             assert (
#                 len(p0) == 3 and len(p1) == 3
#             ), "p0 and p1 must be 3 elements long"

#     fn __init__(out self, p0: Point, p1: List[Scalar[Self.dtype]]):
#         assert len(p1) == 3 or len(p1) == 2, "p1 must be 3 or 2 elements long"
#         self.vec = alloc[Scalar[Self.dtype]](Self.width)
#         if len(p1) == 3:
#             self.vec.store(
#                 p0.load().join(SIMD[Self.dtype, 3](p1[0], p1[1], p1[2]))
#             )
#         else:
#             self.vec.store(
#                 p0.load().join(SIMD[Self.dtype, 3](p1[0], p1[1], 1.0))
#             )

#     @implicit
#     fn __init__(out self, vec: SIMD[Self.dtype, Self.width]):
#         self.vec = alloc[Scalar[Self.dtype]](Self.width)
#         self.vec.store(vec)

#     def write_to(self, mut writer: Some[Writer]):
#         writer.write("Vector(", self.p0(), ", ", self.p1(), ")")

#     def write_repr_to(self, mut writer: Some[Writer]):
#         writer.write("Vector: p0=", self.p0(), ", p1=", self.p1())

#     fn load(self) -> SIMD[Self.dtype, Self.width]:
#         return self.vec.load[Self.width]()

#     fn p0(self) -> Point:
#         return Point(self.load().slice[Point.width, offset=0]())

#     fn p1(self) -> Point:
#         return Point(self.load().slice[Point.width, offset=Point.width]())

#     fn mag(self) -> Point:
#         return self.p1() - self.p0()

#     fn hypot(self) -> Scalar[Self.dtype]:
#         return self.p0().hypot(self.p1())

#     fn join(self, other: Vector) -> SIMD[Self.dtype, Self.width * 2]:
#         "Returns a joined SIMD vector of the two vectors."
#         return self.load().join(other.load())


struct Square:
    comptime width = Vector.width * 4
    comptime dtype = DType.float32

    var vertices: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin]
    # var alphas: nm.NDArray[DType.float32]
    # var colors: nm.NDArray[DType.uint8]
    var color_fill: SIMD[DType.uint8, 4]
    var color_edges: SIMD[DType.uint8, 4]

    def __init__(
        out self,
        *,
        color_fill: SIMD[DType.uint8, 4],
        color_edges: SIMD[DType.uint8, 4] = WHITE,
    ) raises:
        self.vertices = alloc[Scalar[Self.dtype]](Self.width)
        var v0 = Vector([-1.0, -1.0], [1.0, -1.0])
        var v1 = Vector(v0.p1(), [1.0, 1.0])
        var v2 = Vector(v1.p1(), [-1.0, 1.0])
        var v3 = Vector(v2.p1(), [-1.0, -1.0])
        for i, v in enumerate([v0, v1, v2, v3]):
            self.vertices.store(val=v.load(), offset=Vector.width * i)
        # self.vertices.store((v0.join(v1)).join(v2.join(v3)))
        self.color_fill = color_fill
        self.color_edges = color_edges

    def __init__(
        out self,
        v0: Vector,
        v1: Vector,
        v2: Vector,
        v3: Vector,
        *,
        color_fill: SIMD[DType.uint8, 4],
        color_edges: SIMD[DType.uint8, 4] = WHITE,
    ) raises:
        self.vertices = alloc[Scalar[Self.dtype]](Self.width)
        for i, v in enumerate([v0, v1, v2, v3]):
            self.vertices.store(val=v.load(), offset=Vector.width * i)
        self.color_fill = color_fill
        self.color_edges = color_edges

    fn load(self) -> SIMD[Self.dtype, Self.width]:
        return self.vertices.load[Self.width]()

    def v[i: Int](self) -> Vector:
        return self.load().slice[Vector.width, offset=Vector.width * i]()

    def get_draw_fn(self) -> Self.draw_fn:
        var unit_intervals = InlineArray[Float32, 4](fill=0)
        var vectors = InlineArray[Vector, 4](uninitialized=True)
        comptime for i in range(4):
            vectors[i] = self.v[i]()
            print(vectors[i])
        var total_length = (
            vectors[0].hypot()
            + vectors[1].hypot()
            + vectors[2].hypot()
            + vectors[3].hypot()
        )
        comptime for i in range(4):
            unit_intervals[i] = vectors[i].hypot() / total_length

        return Self.draw_fn(unit_intervals^, vectors^, total_length)

    # def flip(self, direction: Vector3D) -> None:
    #     pass

    # def rotate(self, angle: Float32) -> None:
    #     pass
