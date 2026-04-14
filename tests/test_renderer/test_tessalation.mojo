from momanim.data_structs.image import Image
from momanim.constants import ColorSpace
from momanim.io_backends.mav.image_write import image_write
from momanim.mobject.polygram import Circle, Line
from momanim.mobject.bezier_curve import QuadBezierCurve, Point
from momanim.renderer.tessalation import tessellate_line, draw_triangle_strokes, draw_triangle_fill, Triangle
from momanim.typing import Vector3D
from std.pathlib import Path
from std.testing import TestSuite

def test_tessalation() raises:

    var w = 100
    var h = 100

    var frame = alloc[Scalar[DType.uint8]](w * h * 1)
    circle = Circle()
    circle.scale(25.0)
    circle.translate(SIMD[Float32.dtype, 4](50, 50, 0, 0))

    var original_circle = circle.copy()
    # # print("original_circle: ", original_circle.get_curves())
    var partial_circle = circle.pointwise_become_partial(original_circle, 0, 1)

    ref curves = partial_circle.get_curves()
    # var line = Line()
    # line.scale(10.0)
    # line.translate(SIMD[Float32.dtype, 4](50, 50, 0, 0))
    # ref curves = line.get_curves()
    # print("curves: ", curves)
    # print("curves: ", len(curves))

    # TODO: Decide whether we want to pass a list of curves or just the object.
    var triangles = tessellate_line(curves, 0.5)
    # var points = tessellate_line(curves, 1)
    for triangle in triangles:
        draw_triangle_strokes(triangle, frame, w, 1)
        draw_triangle_fill(triangle, frame, w, 1)

    var image = Image(
        w=w, h=h, ch=1,
        ptr=frame, size=w * h * 1, 
        color_space=ColorSpace.GREY_8, 
        line_size=w
    )
    image_write(image, Path("test_tessalation.png"))



def main() raises:
    # TestSuite.discover_tests[__functions_in_module()]().run()
    test_tessalation()
