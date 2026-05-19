from momanim.io_backends.image import Image
from momanim.constants import ColorSpace
from momanim.io_backends.mav.image_write import image_write
# from momanim.mobject.polygram import Circle
# from momanim.mobject.bezier_curve import QuadBezierCurve, Point
# from momanim.renderer.tessalation import tessellate_line, draw_triangle_strokes, draw_triangle_fill, Triangle
# from momanim.typing import Vector3D
# from momanim.mobject.geometry import Point2d, Triangle2d, Trapezoid2d, Vector2d
from std.pathlib import Path
from std.testing import TestSuite
from momanim.utils.color import WHITE, RED
from std.time import perf_counter_ns, time_function
from std.memory import memset_zero
from momanim.rasterization.image import MaskImage
from momanim.rasterization.rasterize import rasterize_edge
from momanim.rasterization.fixed_dtype import FixedInt
from momanim.rasterization.geometry_2d import FixedPointEdge2d, Vector2d, Point2d
from momanim.rasterization.fixed_point_trap_2d import FixedPointTrap2d


def write_frame(frame: MaskImage, path: Path) raises:
    var image = Image(
        w=UInt(frame.width), h=UInt(frame.height), ch=1,
        ptr=frame.buffer, size=frame.line_size * frame.height * 1, 
        color_space=ColorSpace.GREY_8, 
        line_size=UInt(frame.line_size)
    )
    image_write(image, path)

# def test_draw_vector_perfect_angles() capturing raises:
#     var w = 50
#     var h = 50

#     var frame = MaskImage(w, h)

#     var p2s = [
#         ((25.0, 25.0), (49.0, 49.0)),
#         ((25.0, 25.0), (49.0, 25.0)), # vert
#         ((25.0, 24.0), (49.0, 0.0)),
#         ((25.0, 24.0), (25.0, 0.0)), # horz
#         ((24.0, 24.0), (0.0, 0.0)),
#         ((24.0, 24.0), (0.0, 24.0)), # horz
#         ((24.0, 25.0), (0.0, 49.0)),
#         ((24.0, 25.0), (24.0, 49.0)), # vert
#     ]
#     for vec in p2s:
#         var v = Vector2d(
#             p1=Point2d(cast_x=vec[0][0], cast_y=vec[0][1]),
#             p2=Point2d(cast_x=vec[1][0], cast_y=vec[1][1]),
#         )
#         var trapezoids = FixedPointTrapezoid2d.traps_from_edge(v, 0.5)
#         for trapezoid in trapezoids:
#             rasterize_edge(frame, trapezoid)

#     write_frame(frame, Path("test_data/test_rasterization/test_draw_vector_perfect_angles.png"))


# def test_draw_vector_imperfect_angles() capturing raises:
#     var w = 50
#     var h = 50

#     var frame = MaskImage(0, w, h)

#     var p2s = [
#         ((25.0, 25.0), (37.0, 49.0)),
#         ((25.0, 25.0), (49.0, 37.0)),
#         ((25.0, 24.0), (37.0, 0.0)),
#         ((25.0, 24.0), (49.0, 12.0)),
#         ((24.0, 24.0), (12.0, 0.0)),
#         ((24.0, 24.0), (0.0, 12.0)),
#         ((24.0, 25.0), (0.0, 37.0)),
#         ((24.0, 25.0), (12.0, 49.0)),
#     ]
#     for vec in p2s:
#         var v = Vector2d(
#             p1=Point2d(cast_x=vec[0][0], cast_y=vec[0][1]),
#             p2=Point2d(cast_x=vec[1][0], cast_y=vec[1][1]),
#         )
#         var trapezoids = FixedPointTrapezoid2d.traps_from_edge(v, 0.5)
#         for trapezoid in trapezoids:
#             rasterize_edge(frame, trapezoid)

#     write_frame(frame, Path("test_data/test_rasterization/test_draw_vector_imperfect_angles.png"))



def test_draw_trapezoid() capturing raises:
    var w = 100
    var h = 100

    var frame = MaskImage(0, w, h)

    var trap1 = FixedPointTrap2d(
        a=Point2d(cast_x=5.0, cast_y=5.0),
        b=Point2d(cast_x=1.0, cast_y=50.0),
        c=Point2d(cast_x=99.0, cast_y=50.0),
        d=Point2d(cast_x=95.0, cast_y=5.0),
    )
    rasterize_edge(frame, trap1)

    var trap2 = FixedPointTrap2d(
        a=Point2d(cast_x=1.0, cast_y=55.0),
        b=Point2d(cast_x=5.0, cast_y=99.0),
        c=Point2d(cast_x=95.0, cast_y=99.0),
        d=Point2d(cast_x=99.0, cast_y=55.0),
    )
    rasterize_edge(frame, trap2)

    write_frame(frame, Path("test_data/test_rasterize/test_draw_trapezoid.png"))



def test_draw_vector_basic() capturing raises:
    var w = 100
    var h = 100

    var frame = MaskImage(0, w, h)

    var p2s = [
        ((0.0, 0.0), (99.0, 9.0)),
    ]
    for vec in p2s:
        var v = Vector2d(
            p1=Point2d(cast_x=vec[0][0], cast_y=vec[0][1]),
            p2=Point2d(cast_x=vec[1][0], cast_y=vec[1][1]),
        )
        var trapezoids = FixedPointTrap2d.from_line(v, 0.5)
        print("trapezoids.l", trapezoids[0].l.vector_2d[2]())
        print("trapezoids.r", trapezoids[0].r.vector_2d[2]())
        print("trapezoids.top", trapezoids[0].top)
        print("trapezoids.bot", trapezoids[0].bot)
        for trapezoid in trapezoids:
            rasterize_edge(frame, trapezoid)

    write_frame(frame, Path("test_data/test_rasterize/test_draw_vector_basic.png"))


def main() raises:
    # TestSuite.discover_tests[__functions_in_module()]().run()
    # test_draw_vector_basic_color()
    # test_tessalation()
    # test_draw_vector_quarter_circle_segments()
    test_draw_trapezoid()
    # print('test_draw_vector_basic', Float64(time_function[test_draw_vector_basic]()) / 1_000_000_000.0, "seconds")
    # print('test_draw_vector_perfect_angles', Float64(time_function[test_draw_vector_perfect_angles]()) / 1_000_000_000.0, "seconds")
    # print('test_draw_vector_imperfect_angles', Float64(time_function[test_draw_vector_imperfect_angles]()) / 1_000_000_000.0, "seconds")
