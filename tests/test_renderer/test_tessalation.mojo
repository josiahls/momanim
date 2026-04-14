from momanim.data_structs.image import Image
from momanim.constants import ColorSpace
from momanim.io_backends.mav.image_write import image_write
from momanim.mobject.polygram import Circle, Line
from momanim.mobject.bezier_curve import QuadBezierCurve, Point
from momanim.renderer.tessalation import tessellate_line, draw_triangle_strokes
from momanim.typing import Vector3D
from std.pathlib import Path
from std.testing import TestSuite

def test_tessalation() raises:

    var w = 100
    var h = 100

    var frame = alloc[Scalar[DType.uint8]](w * h * 1)
    # circle = Circle()
    # circle.scale(25.0)
    # circle.translate(SIMD[Float32.dtype, 4](50, 50, 0, 0))

    # var original_circle = circle.copy()
    # # print("original_circle: ", original_circle.get_curves())
    # var partial_circle = circle.pointwise_become_partial(original_circle, 0, 1)

    # ref curves = partial_circle.get_curves()
    var line = Line()
    line.scale(10.0)
    line.translate(SIMD[Float32.dtype, 4](50, 50, 0, 0))
    ref curves = line.get_curves()
    print("curves: ", curves)
    # print("curves: ", len(curves))

    # TODO: Decide whether we want to pass a list of curves or just the object.
    var triangles = tessellate_line(curves, 2)
    # var points = tessellate_line(curves, 1)
    for triangle in triangles:
        draw_triangle_strokes(triangle, frame, w, 1)
        # if triangle.points[0] >= 0 and triangle.points[0] <= 100 and triangle.points[1] >= 0 and triangle.points[1] <= 100:
        #     frame.store(val=255, offset=Int(round(triangle.points[1])) * 100 + Int(round(triangle.points[0])))
        # if triangle.points[2] >= 0 and triangle.points[2] <= 100 and triangle.points[3] >= 0 and triangle.points[3] <= 100:
        #     frame.store(val=255, offset=Int(round(triangle.points[3])) * 100 + Int(round(triangle.points[2])))
        # if triangle.points[4] >= 0 and triangle.points[4] <= 100 and triangle.points[5] >= 0 and triangle.points[5] <= 100:
        #     frame.store(val=255, offset=Int(round(triangle.points[5])) * 100 + Int(round(triangle.points[4])))

    # for point in points:
    #     if point.coords[0] >= 0 and point.coords[0] <= 100 and point.coords[1] >= 0 and point.coords[1] <= 100:
    #         frame.store(val=255, offset=Int(round(point.coords[1])) * 100 + Int(round(point.coords[0])))


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
