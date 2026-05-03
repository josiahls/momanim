"""Provides FixedPoint int pirmitves for efficient int based calculations.

Many libraries and algoorithms use int operations for calculations. 
Floating points are converted into fixed point values where their fraction parts
are maintained.
"""

from std.sys.intrinsics import size_of
from std.math import floor, hypot, Floorable
from std.memory import memset_zero
from std.collections import InlineArray

from momanim.rasterization.geometry_2d import Vector2d, Point2d, HalfPlane2d


comptime ByteSize = 8


struct FixedPoint[
    dtype: DType,
    integral_portion: Scalar[dtype] = Scalar[dtype](size_of[dtype]() / 2),
](Comparable, Floorable, ImplicitlyCopyable, Intable, Writable):
    """Represents FixedPoint scalars and enables fixed point arithmetic.

    Parameters:
        dtype: An integral type.
        integral_portion: The number of bits used for representing the integral portion.
            If we suppose `dtype == uint32`, then the bit representation is:

            `FFFF`. The first `FF` is used for the integral portional, while that last `FF`
            is used for the fractional portion.

            It is important to note that the integral portion is assumed to be the
            left portion of the bits.
    """

    comptime scale_int_value = Scalar[Self.dtype](
        Self.integral_portion * ByteSize
    )
    # Fractional scale: 2**fraction_bits. Do not use `(size_of(dtype) - scale_int_value)` —
    # for int32 that's `4 - 16 = -12` and blows up CTFE / `to_real_float`.
    comptime scale_float_value = Float32(1 << Self.scale_int_value)

    comptime one = FixedPoint[Self.dtype, Self.integral_portion](1)
    comptime zero = FixedPoint[Self.dtype, Self.integral_portion](0)
    comptime e = FixedPoint[Self.dtype, Self.integral_portion](
        Scalar[Self.dtype](1)
    )
    "Smallest representable value of `FixedPoint`."
    comptime max_value = FixedPoint[Self.dtype, Self.integral_portion](
        Scalar[Self.dtype](2 ^ (size_of[Self.dtype]() * ByteSize - 1))
    )

    var value: Scalar[Self.dtype]

    def __init__(out self, value: Scalar[Self.dtype]):
        self.value = value

    def __init__(out self, value: FixedPoint[_, _]):
        self.value = Scalar[Self.dtype](value.value)

    def __init__(out self, value: Int):
        if value > 0:
            self.value = Scalar[Self.dtype](value) << Self.scale_int_value
        else:
            self.value = Scalar[Self.dtype](value)

    def __init__(out self, value: Float32):
        self.value = Scalar[Self.dtype](value * Self.scale_float_value)

    def __init__(out self, value: Float64):
        self.value = Scalar[Self.dtype](value * Float64(Self.scale_float_value))

    @staticmethod
    def cast(value: Int) -> Self:
        return Self(Scalar[Self.dtype](value))

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def __lt__(self, other: Self) -> Bool:
        return self.value < other.value

    def __sub__(self, other: Self) -> Self:
        return Self(self.value - other.value)

    def __add__(self, other: Self) -> Self:
        return Self(self.value + other.value)

    def __mul__(self, other: Self) -> Self:
        return Self(self.value * other.value)

    def __mul__(self, other: Int) -> Self:
        return Self(self.value * Scalar[Self.dtype](other))

    def __mod__(self, other: Self) -> Self:
        return Self(self.value % other.value)

    def slow_div(self, other: Self) -> Self:
        """Floating point division of FixedPoint values.

        This is explicit instead of `__div__` since the purpose of FixedPoint
        values is fast integer arithmetic operations.
        """
        return Self(Float64(self.value) / Float64(other.value))

    def __truediv__(self, other: Self) -> Self:
        return {self.value / other.value}

    def __truediv__(self, other: Int) -> Self:
        # TODO: There has to be a nicer way to handle this.
        return {self.value / Scalar[Self.dtype](other)}

    def __and__(self, other: Self) -> Self:
        return Self(self.value & other.value)

    def __rshift__(self, pow_of_2: Int) -> Self:
        return {self.value >> Scalar[Self.dtype](pow_of_2)}

    def __int__(self) -> Int:
        return Int(self.value)

    def to_real_int(self) -> Int:
        return Int(self.value >> Self.scale_int_value)

    def to_real_float(self) -> Float32:
        return Float32(self.value) / Self.scale_float_value

    def get_fractional_part(self) -> Self:
        return self & (Self.one - Self.e)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("(", self.value, ", real:", self.to_real_float(), ")")

    def write_real_to(self, mut writer: Some[Writer]):
        writer.write("(", self.to_real_float(), ")")

    def __neg__(self) -> Self:
        return Self(self.value * -1)

    def __iadd__(mut self, other: Self):
        self.value += other.value

    def __isub__(mut self, other: Self):
        self.value -= other.value

    def __floor__(self) -> Self:
        return Self(self.value & ~(Self.one.value - Self.e.value))

    def __or__(self, other: Self) -> Self:
        return Self(self.value | other.value)


# int64 backing for intermediates (see Pixman `pixman_fixed_48_16_t`), same **16 fractional
# bits** as `FixedInt`: second param is **bytes** of fractional part → 2 * 8 = 16 bits.
comptime FixedPoint48x16 = FixedPoint[DType.int64, 2]
comptime FixedPoint16x16 = FixedPoint[DType.int32]
"""A 16x16 FixedPoint integer.

Where:
- The first 16 bits are the integral
- The last 16 bits are the fractional
"""

comptime FixedInt = FixedPoint16x16
"""The default fixed int representation.
"""


@fieldwise_init
struct PixelSampling[offset: Int, n: Int = 8](Writable):
    comptime samples_per_pixel: Int = (1 << Self.n / 2) + Self.offset
    """The number of rows and columns in a subpixel area.

    Default usage:
    - X direction: 17 columns
    - Y direction: 15 columns
    """
    comptime step_size: FixedInt = FixedInt.one / Self.samples_per_pixel
    "A single unit step repsenting the length of a row or column."
    comptime remainder: FixedInt = FixedInt.one - Self.step_size * (
        Self.samples_per_pixel - 1
    )
    """The remaining coverage units of which does not equal Self.step_size.
    
    Pixel coverage is handled via.:

    `first part, step_size, step_size, ..., step_size, last part`.

    N samples for X is 15 and Y is 17. This is so max coverage can be represented
    as 15 * 17 = 255 which is the most "equal" x and y coverage we can represent
    that cleanly multiplies to 255. 

    For example if `Self.step_size` is `65536 / 15 = 4369 int`

    So each "sample row y" per pixel is 4369 units long. 

    We fail to recover the original total pixel length since 4369 * 15 = 65535.

    We have some alternatives:
    - Deal with the end of the pixel being a 1 unit longer than the others
    Or
    - Place that "extra" unit to be in the center of the pixel instead.

    We opt for the second option. `remainder` is the "slightly larger" step size.
    We divide it in half and distribute it over the start and end of the pixel.
    """
    comptime first_step_size: FixedInt = Self.remainder / 2
    comptime last_step_start: FixedInt = Self.first_step_size + Self.step_size * (
        Self.samples_per_pixel - 1
    )
    """Start of the last subpixel row inside a pixel; Pixman calls this ``Y_FRAC_LAST``."""

    @staticmethod
    def coverage(x: Float32) -> Int:
        comptime if Self.n == 1:
            return 0
        else:
            return Self.coverage(FixedInt(x))

    @staticmethod
    def div_floor(a: FixedInt, b: FixedInt) -> FixedInt:
        """Pixman `DIV`: integer division rounded toward negative infinity."""
        var av = Int(a.value)
        var bv = Int(b.value)
        var q = av / bv
        var r = av % bv
        if r != 0:
            if (av < 0 and bv > 0) or (av > 0 and bv < 0):
                q -= 1
        return FixedInt.cast(q)

    @staticmethod
    def ceil(x: FixedInt) -> FixedInt:
        var f = x.get_fractional_part()
        print("f", f)
        var i = floor(x)
        print("i", i)

        var sample_loc = Self.div_floor(
            f - Self.first_step_size + Self.step_size - FixedInt.e,
            Self.step_size,
        )
        print("sample_loc", sample_loc)
        sample_loc = sample_loc * Self.step_size + Self.first_step_size

        if sample_loc > Self.last_step_start:
            print("doing an adjustment")
            if Int(i) == 32767:
                sample_loc = FixedInt.max_value
            else:
                sample_loc = Self.first_step_size
                i += FixedInt.one
        return i | sample_loc

    @staticmethod
    def floor(x: FixedInt) -> FixedInt:
        var f = x.get_fractional_part()
        var i = floor(x)

        var sample_loc = Self.div_floor(
            f - Self.first_step_size - FixedInt.e,
            Self.step_size,
        )
        sample_loc = sample_loc * Self.step_size + Self.first_step_size

        if sample_loc < Self.first_step_size:
            if Int(i) == 4294934528:
                sample_loc = FixedInt.zero
            else:
                sample_loc = Self.last_step_start
                i -= FixedInt.one
        return i | sample_loc

    @staticmethod
    def coverage(x: FixedInt) -> Int:
        comptime if Self.n == 1:
            return 0
        else:
            # If x.frac() is 0:
            # (x.frac() + first part) / step size == 0
            # If x.frac() is 99 (like 5.99):
            # (x.frac() + first part) / step size == 17
            return Int(
                (x.get_fractional_part() + Self.first_step_size)
                / Self.step_size
            )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "(",
            "samples_per_pixel=",
            Self.samples_per_pixel,
            ", ",
            "step_size=",
            Self.step_size,
            ", ",
            "remainder=",
            Self.remainder,
            ", ",
            "first_step_size=",
            Self.first_step_size,
            ", ",
            "last_step_start=",
            Self.last_step_start,
            ", ",
            ")",
        )


comptime XPixelSampling = PixelSampling[1]
comptime YPixelSampling = PixelSampling[-1]


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
            "("
            + String(self.x.to_real_float())
            + ", "
            + String(self.y.to_real_float())
            + ")"
        )


@fieldwise_init
struct FixedPointEdge2d(Copyable, Movable, Writable):
    var p0: FixedPoint2d
    var p1: FixedPoint2d

    def __init__(out self, p0: Point2d, p1: Point2d):
        self.p0 = FixedPoint2d(p0)
        self.p1 = FixedPoint2d(p1)

    def __init__(out self, edge: Vector2d):
        self.p0 = FixedPoint2d(edge.p1)
        self.p1 = FixedPoint2d(edge.p2)

    def magnitude(self) -> FixedPoint2d:
        return self.p1 - self.p0

    def swap(self) -> Self:
        return {self.p1.copy(), self.p0.copy()}


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
