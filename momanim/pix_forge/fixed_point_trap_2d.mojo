"""Simple non-beazier curve trapezoid pimitive.

All pimitives are `size ** 2` for SIMD compat.
"""
from std.math import Floorable, floor, hypot
from std.memory import memset_zero
from momanim.pix_forge.fixed_dtype import FixedInt
from momanim.pix_forge.geometry_2d import (
    FixedPointEdge2d,
    Point2d,
    Vector2d,
    HalfPlane2d,
)


# TODO: rename to scaline pairs or span or something.
struct Span2d(Copyable, Equatable, Movable, Writable):
    var p0: Point2d
    var p1: Point2d

    def __init__(out self, p0: Point2d, p1: Point2d):
        assert p0.y == p1.y, (
            "p0.y != p1.y. The p0 and p1 must be located on the same y"
            " coordinate. p0.y: {}, p1.y: {}".format(p0.y, p1.y)
        )
        # TODO: Look into just doing `var` e.g. take onership of these points.
        if p0.x <= p1.x:
            self.p0 = p0.copy()
            self.p1 = p1.copy()
        else:
            self.p0 = p1.copy()
            self.p1 = p0.copy()

    def round[round_places: Int = 0](self) -> Self:
        return {self.p0.round[round_places](), self.p1.round[round_places]()}


struct Line2d:
    # Counter clockwise left and right handedness.
    # TODO: Possibly make these pointers and make the v_r and v_l optional.
    # There is the edge case where the line is a narrow one. Alternatively,
    # rename this to ThickLine2d and have NarrowLine2d.
    # Also if this is just a point, we also want to fast path that.
    var v_l: Vector2d
    var v_r: Vector2d
    var slope_l: HalfPlane2d
    var slope_r: HalfPlane2d

    def __init__(out self, vector: Vector2d, thickness: Float32):
        assert (
            thickness >= 0.0
        ), "thickness must be greater than or equal to 0.0"
        # TODO: Remove the copy.
        var norm_slope = HalfPlane2d(vector).ij.copy()
        # TODO: We need to have a version that doesn't return anything or
        # modfify inplace.
        var _ = norm_slope.normalize_slope_()
        # Left / Right in CCW terms.
        self.v_l = vector.copy()
        self.v_r = vector.copy()
        var half_line_width = thickness / 2
        # TODO: Note cairo: third_party/cairo/src/cairo-path-stroke-traps.c
        # line: 615: checks stroker->ctm_inverse. I don't understand this,
        # so im skipping implimenting it.

        # 90 degree rotation.
        # Left / Right in the CCW direction of the edge.
        self.v_l.translate(norm_slope * half_line_width)
        self.v_r.translate(norm_slope * half_line_width * -1.0)

        self.slope_l = HalfPlane2d(self.v_l)
        self.slope_r = HalfPlane2d(self.v_r)

    def into_spans(deinit self) -> List[Span2d]:
        # TODO: Do we want to decompose into dumb points and sort by y,
        # or do we want to leverage some of the semantics context provided by them
        # residing within these vectors?
        var spans = List[Span2d](capacity=4)

        # TODO: This should be simplified. This should be doable when updating
        # to mojo 1.0.0.b1 since they have better support for unpacking.

        # Initialize a,b,c,d, however these are in the wrong order since
        # we need to decompose these into up to 3 trapezoids, sorted
        # lowest y -> highest y for our scanline rasterization algs.
        var points: InlineArray[UnsafePointer[Point2d, ImmutAnyOrigin], 4] = [
            UnsafePointer(to=self.v_l.p1).as_any_origin(),
            UnsafePointer(to=self.v_l.p2).as_any_origin(),
            UnsafePointer(to=self.v_r.p1).as_any_origin(),
            UnsafePointer(to=self.v_r.p2).as_any_origin(),
        ]
        # The edge line opposite the respective edge. Used for synthesizing
        # missing points when slicing out trapezoids.
        var opposite_slopes: InlineArray[
            UnsafePointer[HalfPlane2d, ImmutAnyOrigin], 4
        ] = [
            UnsafePointer(to=self.slope_r).as_any_origin(),
            UnsafePointer(to=self.slope_r).as_any_origin(),
            UnsafePointer(to=self.slope_l).as_any_origin(),
            UnsafePointer(to=self.slope_l).as_any_origin(),
        ]
        # Goal is for the indicies to be sorted by y:
        #
        #   x ------> +
        # y   a<--d
        # |   |   ^
        # v   v   |
        # +   b---c
        var indicies: InlineArray[Int, 4] = [0, 1, 2, 3]

        def cmp_point(a: Int, b: Int) capturing -> Bool:
            if points[a][].y == points[b][].y:
                return points[a][].x < points[b][].x
            return points[a][].y < points[b][].y

        sort[cmp_point](Span(indicies))

        # TODO: Place with cleaner unpacking when updating to mojo 1.0.0.b1.
        if points[indicies[0]][].y == points[indicies[1]][].y:
            spans.append(
                {points[indicies[0]][].copy(), points[indicies[1]][].copy()}
            )
        else:
            spans.append(
                {points[indicies[0]][].copy(), points[indicies[0]][].copy()}
            )
            spans.append(
                {
                    opposite_slopes[indicies[1]][].point_from_y(
                        points[indicies[1]][].y
                    ),
                    points[indicies[1]][].copy(),
                }
            )

        if points[indicies[2]][].y == points[indicies[3]][].y:
            spans.append(
                {points[indicies[2]][].copy(), points[indicies[3]][].copy()}
            )
        else:
            spans.append(
                {
                    opposite_slopes[indicies[2]][].point_from_y(
                        points[indicies[2]][].y
                    ),
                    points[indicies[2]][].copy(),
                }
            )
            spans.append(
                {points[indicies[3]][].copy(), points[indicies[3]][].copy()}
            )

        return spans^


@fieldwise_init
struct FixedPointTrap2d(Copyable):
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

        ```
        `a` ----- `d`
         |         ^
         v         |
         `b` ----- `c`
        ```
        """
        assert a.y == d.y, (
            "a.y != d.y. The a and d must be located on the same y coordinate."
            " a.y: {}, d.y: {}".format(a.y, d.y)
        )
        assert b.y == c.y, (
            "b.y != c.y. The b and c must be located on the same y coordinate."
            " b.y: {}, c.y: {}".format(b.y, c.y)
        )
        assert b.x <= c.x, (
            "b.x > c.x. The b and c must be located on the same x coordinate."
            " b.x: {}, c.x: {}".format(b.x, c.x)
        )
        assert a.x <= d.x, (
            "a.x > d.x. The a and d must be located on the same x coordinate."
            " a.x: {}, d.x: {}".format(a.x, d.x)
        )
        self.l = FixedPointEdge2d(a, b)
        self.r = FixedPointEdge2d(c, d)
        # We asserted that a.y and d.y are the same.
        self.top = FixedInt(from_float=a.y)
        # We asserted that b.y and c.y are the same.
        self.bot = FixedInt(from_float=c.y)

    def __init__(out self, top: Span2d, bot: Span2d):
        """Creates a `Self` from a `top` span (low y value) and `bot` span (high y value).

        ```
           x ------> +
         y   top.p0<--top.p1
         |    |          ^
         v    v          |
         +   bot.p0---bot.p1
        ```
        """
        # TODO: would really like to just "decompose" into single points :(
        var a = top.p0.copy()
        var b = bot.p0.copy()
        var c = bot.p1.copy()
        var d = top.p1.copy()
        self = Self(a, b, c, d)

    def is_degenerate(self) -> Bool:
        if self.top == self.bot:
            # Effectively a horz line or point.
            return True
        elif self.l.p0.x == self.l.p1.x == self.r.p0.x == self.r.p1.x:
            # Effectively a vert line or point.
            return True
        elif self.l.p0 == self.r.p1:
            # Effectively a triangle.
            return True
        elif self.l.p1 == self.r.p0:
            # Effectively a triangle.
            return True
        return False

    @staticmethod
    def from_line(vector: Vector2d, thickness: Float32) -> List[Self]:
        var line_2d = Line2d(vector, thickness)
        return Self.from_line(line_2d^)

    @staticmethod
    def from_line(var line: Line2d) -> List[Self]:
        var spans = line^.into_spans()
        return Self.from_spans(spans^)

    @staticmethod
    def from_spans(spans: List[Span2d]) -> List[Self]:
        # print("making trap:")
        var traps = List[Self](capacity=len(spans))
        if len(spans) == 1:
            traps.append({top = spans[0], bot = spans[0]})
            return traps^
        for i in range(len(spans) - 1):
            # print("spans[i]", spans[i], "spans[i + 1]", spans[i + 1])
            traps.append({top = spans[i], bot = spans[i + 1]})
        return traps^
