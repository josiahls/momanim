from momanim.io_backends.image import Image
from momanim.constants import ColorSpace
from momanim.io_backends.mav.image_write import image_write
# from momanim.mobject.polygram import Circle, Line
# from momanim.mobject.bezier_curve import QuadBezierCurve, Point
# from momanim.renderer.tessalation import tessellate_line, draw_triangle_strokes, draw_triangle_fill, Triangle
# from momanim.typing import Vector3D
from momanim.mobject.geometry import Point2d, Triangle2d, Trapezoid2d, Vector2d
from momanim.renderer.tessalation import draw_vector
from std.pathlib import Path
from std.testing import TestSuite
from momanim.utils.color import WHITE

# def test_tessalation() raises:

#     var w = 100
#     var h = 100

#     var frame = alloc[Scalar[DType.uint8]](w * h * 1)
#     circle = Circle()
#     circle.scale(15.0)
#     circle.translate(SIMD[Float32.dtype, 4](50, 50, 0, 0))

#     var original_circle = circle.copy()
#     # # print("original_circle: ", original_circle.get_curves())
#     var partial_circle = circle.pointwise_become_partial(original_circle, 0, 1)

#     ref curves = partial_circle.get_curves()
#     # var line = Line()
#     # line.scale(10.0)
#     # line.translate(SIMD[Float32.dtype, 4](50, 50, 0, 0))
#     # ref curves = line.get_curves()
#     # print("curves: ", curves)
#     # print("curves: ", len(curves))

#     # TODO: Decide whether we want to pass a list of curves or just the object.
#     var triangles = tessellate_line(curves, 0.0)
#     # var points = tessellate_line(curves, 1)
#     for triangle in triangles:
#         draw_triangle_strokes(triangle, frame, w, 1)
#         draw_triangle_fill(triangle, frame, w, 1)

#     var image = Image(
#         w=w, h=h, ch=1,
#         ptr=frame, size=w * h * 1, 
#         color_space=ColorSpace.GREY_8, 
#         line_size=w
#     )
#     image_write(image, Path("test_tessalation.png"))


def test_draw_vector() raises:
    var w = 50
    var h = 50

    var frame = alloc[Scalar[DType.uint8]](w * h * 1)


    var p1 = Point2d(0.0, 0.0)
    # var p2 = Point2d(49.0, 25.0)

    var p2 = Point2d(49.0, 48.0)

    var v1 = Vector2d(p1.copy(), p2.copy())

    draw_vector(
        v1, 
        frame, 
        Scalar[UInt8.dtype](255),
        # WHITE, 
        w, 
        w, 
        h
    )

    var image = Image(
        w=w, h=h, ch=1,
        ptr=frame, size=w * h * 1, 
        color_space=ColorSpace.GREY_8, 
        line_size=w
    )
    image_write(image, Path("test_data/test_renderer/test_draw_vector.png"))



# def test_tessalation() raises:

#     var w = 20
#     var h = 20

#     var frame = alloc[Scalar[DType.uint8]](w * h * 1)


#     var p1 = Point2d(0.0, 4.0)
#     var p2 = Point2d(8.0, 12.0)
#     var p3 = Point2d(0.0, 10.0)
#     var p4 = Point2d(-8.0, 12.0)

#     var v1 = Vector2d(p1.copy(), p2.copy())
#     var v2 = Vector2d(p2.copy(), p3.copy())
#     var v3 = Vector2d(p3.copy(), p4.copy())
#     var v4 = Vector2d(p4.copy(), p1.copy())

#     # var t1 = Triangle2d(p1.copy(), p2^, p3.copy())
#     # var t2 = Triangle2d(p1^, p3^, p4^)
#     # var t = Trapezoid2d(t1^, t2^)
#     # var line = Line()
#     # line.scale(10.0)
#     # line.translate(SIMD[Float32.dtype, 4](50, 50, 0, 0))
#     # ref curves = line.get_curves()
#     # print("curves: ", curves)
#     # print("curves: ", len(curves))

#     # TODO: Decide whether we want to pass a list of curves or just the object.
#     # var triangles = tessellate_line(curves, 0.0)
#     # var points = tessellate_line(curves, 1)
#     # for triangle in triangles:
#     #     draw_triangle_strokes(triangle, frame, w, 1)
#     #     draw_triangle_fill(triangle, frame, w, 1)

#     draw_vector(v1, frame, w, w, h)

#     var image = Image(
#         w=w, h=h, ch=1,
#         ptr=frame, size=w * h * 1, 
#         color_space=ColorSpace.GREY_8, 
#         line_size=w
#     )
#     image_write(image, Path("test_data/test_tessalation.png"))



def main() raises:
    # TestSuite.discover_tests[__functions_in_module()]().run()
    test_draw_vector()
