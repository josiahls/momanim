from std.testing import TestSuite, assert_equal
from momanim.constants import ColorSpace, RIGHT, ORIGIN, CACHE_LINE_SIZE
from std.math import tau, sqrt, round
from std.os import getenv
from std.pathlib import Path
from std.os.path import join
from momanim.scene.scene import Scenable
from momanim.mobject.polygram import Square, Circle
from momanim.data_structs.video import Video
from momanim.io_backends.mav.video_write import video_write
from momanim.scene.scene import Scenable
from momanim.typing import Vector3D
from std.utils.variant import Variant
from momanim.renderer.basic_renderer import BasicRenderer, Create
from momanim.animation.transform import Transform
from momanim.camera.camera import Camera
import numojo as nm
from momanim.animation.animation import Animatable
# from momanim.animation.animation import Animatable
# from momanim.animation.creation import Create
# from momanim.renderer.basic_renderer import BasicRenderer

from momanim.utils.color import rgb, rgba, WHITE, BLACK, BLUE_E
from momanim.mobject.bezier_curve import QuadBezierCurve, Point



struct SquareToCircle(Scenable):
    var camera: Camera
    var _background_color: SIMD[DType.uint8, 4]
    var renderer: UnsafePointer[BasicRenderer[Self], MutExternalOrigin]

    def __init__(out self) raises:
        self.camera = Camera(480, 864)
        # TODO: I wonder if camera should just to passed directly to renderer.
        # self.camera = Camera(240, 432)
        self._background_color = BLACK
        self.renderer = alloc[BasicRenderer[Self]](1)
        self.renderer[] = BasicRenderer[Self](
            UnsafePointer(to=self).unsafe_origin_cast[MutExternalOrigin](),
            fps=12,
            max_duration_seconds=4,
        )

    def play[T: Animatable](mut self, var animation: T) raises -> None:
        self.renderer[].play(animation)

    def cameras(self) -> List[Camera]:
        return [self.camera]

    def background_color(self) -> SIMD[DType.uint8, 4]:
        return self._background_color

    def construct(mut self) raises:
        circle = Circle(color_fill=BLACK)
        circle.scale(100.0)
        var square = Square(
            QuadBezierCurve(
                Point(Float32(-1.0), Float32(0.0)) * 100,
                Point(Float32(0.0), Float32(-1.0)) * 100,
            ),
            QuadBezierCurve(
                Point(Float32(0.0), Float32(-1.0)) * 100,  
                Point(Float32(1.0), Float32(0.0)) * 100,
            ),
            QuadBezierCurve(
                Point(Float32(1.0), Float32(0.0)) * 100,  
                Point(Float32(0.0), Float32(1.0)) * 100),
            QuadBezierCurve(
                Point(Float32(0.0), Float32(1.0)) * 100, 
                Point(Float32(-1.0), Float32(0.0)) * 100,
            ),
            color_fill=BLACK
        )
        # square.flip(RIGHT)
        # square.rotate(-3 * tau / 8)
        # circle.set_fill(PINK, opacity=0.5)

        self.play(Create(square, run_time=2.0))
        # self.play(Create(circle, run_time=2.0))
        self.play(Transform(square, circle))
        # self.play(FadeOut(square))

    def render(mut self, path: Path) raises -> None:
        self.construct()
        self.renderer[].render(path)


def test_SquareToCircle() raises:
    var scene = SquareToCircle()
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    # scene.render(Path(join(test_data_root, "test_data/test_example/test_SquareToCircle.webm")))
    # scene.render(Path(join(test_data_root, "test_data/test_example/test_SquareToCircle.mp4")))
    scene.render(Path(join(test_data_root, "test_data/test_example/test_SquareToCircle.gif")))

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
