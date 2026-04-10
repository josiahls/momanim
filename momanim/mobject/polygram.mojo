from momanim.typing import Vector3D
import numojo as nm
from std.math import sqrt, tan, pi
from momanim.utils.color import WHITE, TRANSPARENT
from momanim.mobject.bezier_curve import (
    QuadBezierCurve,
    Point,
    integer_interpolate,
    farin_rational_de_casteljau_between,
    farin_rational_de_casteljau,
)


trait MObject(Copyable, Writable):
    """Coordinate / curve floating-point element type (e.g. ``Square``'s ``dtype``).

    Used so ``get_curve`` can return ``QuadBezierCurve[Self.CoordDType]`` without a
    generic parameter: callers through ``Some[MObject]`` cannot infer a
    ``[curve_dtype: DType]`` argument.
    """

    comptime CoordDType: DType

    def pointwise_become_partial(
        mut self,
        vmobject: Self,
        a: Float32,
        b: Float32,
    ) -> Self:
        """Given a 2nd :class:`.VMobject` ``vmobject``, a lower bound ``a`` and
        an upper bound ``b``, modify this :class:`.VMobject`'s points to
        match the portion of the Bézier spline described by ``vmobject.points``
        with the parameter ``t`` between ``a`` and ``b``.

        Parameters
        ----------
        vmobject
            The :class:`.VMobject` that will serve as a model.
        a
            The lower bound for ``t``.
        b
            The upper bound for ``t``

        Returns
        -------
        :class:`.VMobject`
            The :class:`.VMobject` itself, after the transformation.

        Raises
        ------
        TypeError
            If ``vmobject`` is not an instance of :class:`VMobject`.
        """

        # Partial curve includes three portions:
        # - A middle section, which matches the curve exactly.
        # - A start, which is some ending portion of an inner cubic.
        # - An end, which is the starting portion of a later inner cubic.
        if a <= 0 and b >= 1:
            self.set_curves(
                vmobject.copy_curves()
            )  # TODO: This is not optimal, fix this
            return self.copy()  # TODO: This is not optimal, fix this
        var num_curves = vmobject.n_curves()
        if num_curves == 0:
            return self.copy()  # TODO: This is not optimal, fix this

        # The following two lines will compute which Bézier curves of the given Mobject must be processed.
        # The residue indicates the proportion of the selected Bézier curve which must be selected.
        #
        # Example: if num_curves is 10, a is 0.34 and b is 0.78, then:
        # - lower_index is 3 and lower_residue is 0.4, which means the algorithm will look at the 3rd Bézier
        #   and select its part which ranges from t=0.4 to t=1.
        # - upper_index is 7 and upper_residue is 0.8, which means the algorithm will look at the 7th Bézier
        #   and select its part which ranges from t=0 to t=0.8.
        var lower_index, lower_residue = integer_interpolate(0, num_curves, a)
        var upper_index, upper_residue = integer_interpolate(0, num_curves, b)

        var nppc = Int(QuadBezierCurve.size)

        # Copy vmobject.points if vmobject is self to prevent unintended in-place modification
        var vmobject_points = vmobject.copy_curves()

        # If both indices coincide, get a part of a single Bézier curve.
        if lower_index == upper_index:
            # print('lower_index == upper_index and a: ', a, ' b: ', b, 'lower_index: ', lower_index, 'lower_residue: ', lower_residue, 'upper_residue: ', upper_residue)
            # Look at the "lower_index"-th Bézier curve and select its part from
            # t=lower_residue to t=upper_residue.
            var curves = List[QuadBezierCurve[Self.CoordDType]](capacity=1)
            # print('vmobject_points[lower_index]: ', vmobject_points[lower_index])
            # vmobject_points[nppc * lower_index : nppc * (lower_index + 1)],
            curves.append(
                farin_rational_de_casteljau_between(
                    vmobject_points[lower_index],
                    lower_residue,
                    upper_residue,
                )
            )
            self.set_curves(curves^)
        else:
            # Allocate space for (upper_index-lower_index+1) Bézier curves.
            # print('\tupper_index - lower_index + 1: ', upper_index - lower_index + 1, ' lower_index: ', lower_index, ' upper_index: ', upper_index, 'lower_residue: ', lower_residue, 'upper_residue: ', upper_residue)
            var n_new_curves = Int((upper_index - lower_index + 1))
            var curves = List[QuadBezierCurve[Self.CoordDType]](
                capacity=n_new_curves
            )

            # Look at the "lower_index"-th Bezier curve and select its part from
            # t=lower_residue to t=1. This is the first curve in self.points.
            # print('\tfirst_curve: ', vmobject_points[lower_index])
            var first_curve = farin_rational_de_casteljau_between(
                # vmobject_points[nppc * lower_index : nppc * (lower_index + 1)],
                vmobject_points[lower_index],
                lower_residue,
                1,
            )
            curves.append(first_curve)
            # If there are more curves between the "lower_index"-th and the
            # "upper_index"-th Béziers, add them all to self.points.
            var between_curves = vmobject_points[
                (lower_index + 1) : upper_index
            ]
            curves.extend(between_curves)
            # Look at the "upper_index"-th Bézier curve and select its part from
            # t=0 to t=upper_residue. This is the last curve in self.points.
            var last_curve = farin_rational_de_casteljau_between(
                vmobject_points[upper_index],
                0,
                upper_residue,
            )
            curves.append(last_curve)
            self.set_curves(curves^)

        return self.copy()  # TODO: This is not optimal, fix this

    def get_curves[
        o: Origin
    ](ref[o] self) -> ref[o] List[QuadBezierCurve[Self.CoordDType]]:
        ...

    def copy_curves(self) -> List[QuadBezierCurve[Self.CoordDType]]:
        ...

    def set_curves(
        mut self, var curves: List[QuadBezierCurve[Self.CoordDType]]
    ) -> None:
        ...

    def n_curves(self) -> Int:
        ...

    def get_curve(self, index: Int) -> QuadBezierCurve[Self.CoordDType]:
        ...

    def get_style(self) -> Style:
        ...


@fieldwise_init
struct Style(Copyable, Writable):
    comptime kernel_size: Int = 3
    var color_fill: SIMD[DType.uint8, 4]
    var color_edges: SIMD[DType.uint8, 4]
    var continuous: Bool


struct Square[dtype: DType = DType.float32](MObject):
    comptime CoordDType = Self.dtype
    comptime width = 4
    var curves: List[QuadBezierCurve[Self.dtype]]
    # var alphas: nm.NDArray[DType.float32]
    # var colors: nm.NDArray[DType.uint8]
    var color_fill: SIMD[DType.uint8, 4]
    var color_edges: SIMD[DType.uint8, 4]

    def __init__(
        out self,
        *,
        color_fill: SIMD[DType.uint8, 4] = TRANSPARENT,
        color_edges: SIMD[DType.uint8, 4] = WHITE,
    ) raises:
        self.curves = [
            QuadBezierCurve[Self.dtype](
                Point[Self.dtype](
                    Scalar[Self.dtype](-1.0), Scalar[Self.dtype](0.0)
                ),
                Point[Self.dtype](
                    Scalar[Self.dtype](0.0), Scalar[Self.dtype](1.0)
                ),
            ),
            QuadBezierCurve[Self.dtype](
                Point[Self.dtype](
                    Scalar[Self.dtype](0.0), Scalar[Self.dtype](1.0)
                ),
                Point[Self.dtype](
                    Scalar[Self.dtype](1.0), Scalar[Self.dtype](0.0)
                ),
            ),
            QuadBezierCurve[Self.dtype](
                Point[Self.dtype](
                    Scalar[Self.dtype](1.0), Scalar[Self.dtype](0.0)
                ),
                Point[Self.dtype](
                    Scalar[Self.dtype](0.0), Scalar[Self.dtype](-1.0)
                ),
            ),
            QuadBezierCurve[Self.dtype](
                Point[Self.dtype](
                    Scalar[Self.dtype](0.0), Scalar[Self.dtype](-1.0)
                ),
                Point[Self.dtype](
                    Scalar[Self.dtype](-1.0), Scalar[Self.dtype](0.0)
                ),
            ),
        ]

        self.color_fill = color_fill
        self.color_edges = color_edges

    def __init__(
        out self,
        curve1: QuadBezierCurve[Self.dtype],
        curve2: QuadBezierCurve[Self.dtype],
        curve3: QuadBezierCurve[Self.dtype],
        curve4: QuadBezierCurve[Self.dtype],
        *,
        color_fill: SIMD[DType.uint8, 4] = TRANSPARENT,
        color_edges: SIMD[DType.uint8, 4] = WHITE,
    ) raises:
        self.curves = [curve1, curve2, curve3, curve4]
        self.color_fill = color_fill
        self.color_edges = color_edges

    def n_curves(self) -> Int:
        return len(self.curves)

    def get_curve(self, index: Int) -> QuadBezierCurve[Self.CoordDType]:
        return self.curves[index]

    def get_curves[
        o: Origin
    ](ref[o] self) -> ref[o] List[QuadBezierCurve[Self.CoordDType]]:
        return UnsafePointer(to=self.curves).unsafe_origin_cast[
            origin_of(self)
        ]()[]

    def copy_curves(self) -> List[QuadBezierCurve[Self.CoordDType]]:
        return self.curves.copy()^

    def set_curves(
        mut self, var curves: List[QuadBezierCurve[Self.CoordDType]]
    ) -> None:
        self.curves = curves^

    def get_style(self) -> Style:
        return Style(
            color_fill=self.color_fill,
            color_edges=self.color_edges,
            continuous=True,
        )

    # def flip(self, direction: Vector3D) -> None:
    #     pass

    # def rotate(self, angle: Float32) -> None:
    #     pass


struct Circle[dtype: DType = DType.float32](MObject):
    comptime CoordDType = Self.dtype
    var curves: List[QuadBezierCurve[Self.CoordDType]]
    var style: Style

    def __init__(
        out self,
        *,
        color_fill: SIMD[DType.uint8, 4] = TRANSPARENT,
        color_edges: SIMD[DType.uint8, 4] = WHITE,
    ) raises:
        # comptime assert Self.dtype.is_floating_point()
        # Cubic Bézier approximation of a unit circle.
        # kappa = 4/3 * tan(pi/8) ~= 0.5522847498
        comptime kappa = Scalar[Self.dtype](0.5522847498)
        self.curves = [
            QuadBezierCurve[Self.dtype](
                Point[Self.dtype](
                    Scalar[Self.dtype](-1.0), Scalar[Self.dtype](0.0)
                ),
                Point[Self.dtype](Scalar[Self.dtype](-1.0), kappa),
                Point[Self.dtype](-kappa, Scalar[Self.dtype](1.0)),
                Point[Self.dtype](
                    Scalar[Self.dtype](0.0), Scalar[Self.dtype](1.0)
                ),
            ),
            QuadBezierCurve[Self.dtype](
                Point[Self.dtype](
                    Scalar[Self.dtype](0.0), Scalar[Self.dtype](1.0)
                ),
                Point[Self.dtype](kappa, Scalar[Self.dtype](1.0)),
                Point[Self.dtype](Scalar[Self.dtype](1.0), kappa),
                Point[Self.dtype](
                    Scalar[Self.dtype](1.0), Scalar[Self.dtype](0.0)
                ),
            ),
            QuadBezierCurve[Self.dtype](
                Point[Self.dtype](
                    Scalar[Self.dtype](1.0), Scalar[Self.dtype](0.0)
                ),
                Point[Self.dtype](Scalar[Self.dtype](1.0), -kappa),
                Point[Self.dtype](kappa, Scalar[Self.dtype](-1.0)),
                Point[Self.dtype](
                    Scalar[Self.dtype](0.0), Scalar[Self.dtype](-1.0)
                ),
            ),
            QuadBezierCurve[Self.dtype](
                Point[Self.dtype](
                    Scalar[Self.dtype](0.0), Scalar[Self.dtype](-1.0)
                ),
                Point[Self.dtype](-kappa, Scalar[Self.dtype](-1.0)),
                Point[Self.dtype](Scalar[Self.dtype](-1.0), -kappa),
                Point[Self.dtype](
                    Scalar[Self.dtype](-1.0), Scalar[Self.dtype](0.0)
                ),
            ),
        ]

        self.style = Style(
            color_fill=color_fill,
            color_edges=color_edges,
            continuous=True,
        )

    def n_curves(self) -> Int:
        return len(self.curves)

    def scale(mut self, factor: Scalar[Self.CoordDType]) -> None:
        for ref curve in self.curves:
            curve *= factor

    def get_curve(self, index: Int) -> QuadBezierCurve[Self.CoordDType]:
        return self.curves[index]

    def get_curves[
        o: Origin
    ](ref[o] self) -> ref[o] List[QuadBezierCurve[Self.CoordDType]]:
        return UnsafePointer(to=self.curves).unsafe_origin_cast[
            origin_of(self)
        ]()[]

    def copy_curves(self) -> List[QuadBezierCurve[Self.CoordDType]]:
        return self.curves.copy()

    def set_curves(
        mut self, var curves: List[QuadBezierCurve[Self.CoordDType]]
    ) -> None:
        self.curves = curves^

    def get_style(self) -> Style:
        return self.style.copy()  # TODO: Turn into a reference

    def set_fill(
        mut self, color: SIMD[DType.uint8, 4], opacity: Float32 = 1.0
    ) -> None:
        if opacity != 1.0:
            self.style.color_fill = SIMD[DType.uint8, 4](
                color[0], color[1], color[2], UInt8(opacity * 255.0)
            )
        else:
            self.style.color_fill = color


struct MorphingVMObject[
    source_dtype: DType = DType.float32, target_dtype: DType = DType.float32
](MObject):
    comptime CoordDType = Self.target_dtype
    var curves: List[QuadBezierCurve[Self.CoordDType]]
    var start_curves: List[QuadBezierCurve[Self.source_dtype]]
    var end_curves: List[QuadBezierCurve[Self.CoordDType]]
    var start_style: Style
    var end_style: Style
    var current_style: Style

    def __init__(
        out self,
        *,
        var start_curves: List[QuadBezierCurve[Self.source_dtype]],
        var end_curves: List[QuadBezierCurve[Self.CoordDType]],
        # TODO: Style should just be a pointer
        var start_style: Style,
        var end_style: Style,
    ) raises:
        self.start_curves = start_curves^
        self.end_curves = end_curves^
        self.start_style = start_style^
        self.end_style = end_style^
        self.current_style = self.start_style.copy()
        self.curves = List[QuadBezierCurve[Self.CoordDType]](
            capacity=len(self.end_curves)
        )

        var start_to_end_step = Float32(len(self.end_curves)) / Float32(
            len(self.start_curves)
        )
        for i in range(len(self.end_curves)):
            ref end_curve = self.end_curves[i]
            var start_index = Int(round(Float32(i) * start_to_end_step))
            ref start_curve = self.start_curves[start_index]
            comptime for j in range(type_of(end_curve).size):
                var curve = QuadBezierCurve[Self.CoordDType](
                    start_curve.points[j].cast[Self.CoordDType](),
                    end_curve.points[j],
                )
                # print('points: ')
                # print("\tsquare points added: ", curve.points[0])
                # print("\tcircle points added: ", curve.points[3])
                self.curves.append(curve)

    def n_curves(self) -> Int:
        return len(self.curves)

    def get_curve(self, index: Int) -> QuadBezierCurve[Self.CoordDType]:
        return self.curves[index]

    def get_curves[
        o: Origin
    ](ref[o] self) -> ref[o] List[QuadBezierCurve[Self.CoordDType]]:
        return UnsafePointer(to=self.curves).unsafe_origin_cast[
            origin_of(self)
        ]()[]

    def morph(
        mut self,
        starting_mobject: Self,
        a: Float32,
        b: Float32,
    ) -> Self:
        var copy_obj = self.parallel_become_partial(
            starting_mobject,
            a=a,
            b=b,
        )
        return copy_obj^

    def parallel_become_partial(
        mut self,
        vmobject: Self,
        a: Float32,
        b: Float32,
    ) -> Self:
        "Gets new curves run all at once."
        # if a <= 0 and b >= 1:
        #     self.set_curves(
        #         vmobject.copy_curves()
        #     )  # TODO: This is not optimal, fix this
        #     return self.copy()  # TODO: This is not optimal, fix this
        var num_curves = vmobject.n_curves()
        if num_curves == 0:
            return self.copy()  # TODO: This is not optimal, fix this

        var nppc = Int(QuadBezierCurve.size)

        # Copy vmobject.points if vmobject is self to prevent unintended in-place modification
        var vmobject_points = vmobject.copy_curves()

        var curves = List[QuadBezierCurve[Self.CoordDType]](capacity=num_curves)
        var t: Float32
        if b > 1 or a > 1:
            t = 1.0
        elif b <= 0:
            t = 0.0
        else:
            # TODO: Is there a better way to handle a? Its not used for much.
            t = b
        # print("a: ", a, " b: ", b, " t: ", t)
        for i in range(len(self.end_curves)):
            var points = List[Point[Self.CoordDType]](
                capacity=QuadBezierCurve.size
            )

            comptime for j in range(QuadBezierCurve.size):
                ref curve = vmobject_points[i * QuadBezierCurve.size + j]

                var point: Point[Self.CoordDType] = farin_rational_de_casteljau(
                    curve, t
                )
                # print("\t\t point: ", point, " curve: ", curve.points[0])
                points.append(point)

            # print("points: ", points)
            curves.append(
                QuadBezierCurve[Self.CoordDType](
                    points[0], points[1], points[2], points[3]
                )
            )
        self.set_curves(curves^)
        return self.copy()  # TODO: This is not optimal, fix this

    def copy_curves(self) -> List[QuadBezierCurve[Self.CoordDType]]:
        return self.curves.copy()

    def set_curves(
        mut self, var curves: List[QuadBezierCurve[Self.CoordDType]]
    ) -> None:
        self.curves = curves.copy()

    def get_style(self) -> Style:
        return self.current_style.copy()  # TODO: Turn into a reference
