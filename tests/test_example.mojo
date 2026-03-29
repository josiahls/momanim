from std.testing import TestSuite, assert_equal
from momanim.constants import ColorSpace, RIGHT, ORIGIN
from std.math import tau
from std.os import getenv
from std.pathlib import Path
from std.os.path import join
from momanim.scene.scene import Scenable
from momanim.mobject.geometry.polygram import Square
from momanim.data_structs.video import Video
from momanim.io_backends.mav.video_write import video_write
from momanim.typing import Vector3D
import numojo as nm
# from momanim.animation.animation import Animatable
# from momanim.animation.creation import Create
# from momanim.renderer.basic_renderer import BasicRenderer

fn rgb(r: UInt8, g: UInt8, b: UInt8) -> SIMD[DType.uint8, 4]:
    "Returns RGBA with alpha = 255."
    return SIMD[DType.uint8, 4](r, g, b, 255)


fn rgba(r: UInt8, g: UInt8, b: UInt8, a: Float32) -> SIMD[DType.uint8, 4]:
    return SIMD[DType.uint8, 4](r, g, b, UInt8(a * 255.0))



comptime WHITE = rgb(255, 255, 255)
comptime BLUE_E = rgb(39, 114, 151)



struct Create[origin: Origin](Movable, ImplicitlyDestructible): #(Animatable):
    var obj: Pointer[Square, Self.origin]
    var run_time: Float32
    "The time the animation will run for in seconds."

    def __init__(out self, ref[Self.origin] obj: Square) raises:
        self.obj = Pointer(to=obj)
        self.run_time = 3

    def interpolate(self, delta: Float32) -> None:
        """Interpolate the animation.
        
        Args:
            delta: Range 0 -> 1 of animation progress.
        """
        pass


struct BasicRenderer(Movable):
    var scene: UnsafePointer[SquareToCircle, MutExternalOrigin]
    var fps: UInt
    var max_duration_seconds: Float32
    var videos: List[Video[DType.uint8]]
    var frame: UInt

    def __init__(out self, scene_ptr: UnsafePointer[SquareToCircle, MutExternalOrigin]) raises:
        self.scene = scene_ptr
        self.fps = 1
        self.frame = 0 # TODO: Should this really be a field?
        self.max_duration_seconds = 5.0
        self.videos = List[Video[DType.uint8]]()
        self.videos.append(Self.video_from_camera(self.scene[].camera))

    @staticmethod
    def video_from_camera(camera: Camera) raises -> Video[DType.uint8]:
        var video = Video[DType.uint8](
            w=camera.pixel_width,
            h=camera.pixel_height,
            ch=4,
            color_space=ColorSpace.RGBA_32,
        )
        return video^

    @staticmethod
    def frame_from_camera(camera: Camera, channels: Int) raises -> nm.NDArray[DType.uint8]:
        return nm.zeros[DType.uint8](
            nm.Shape(
                Int(camera.pixel_width),
                Int(camera.pixel_height),
                channels,
            )
        )

    @staticmethod
    def render_frame(mut video: Video[DType.uint8], camera: Camera, mut scene: SquareToCircle) raises:
        var channels = len(scene.background_color)
        var new_frame = Self.frame_from_camera(camera, channels)
        for ch in range(channels):
            var mat = nm.Matrix(new_frame[
                nm.Slice(0, Int(camera.pixel_width)),
                nm.Slice(0, Int(camera.pixel_height)),
                ch
            ])
            mat.fill(scene.background_color[ch])

        var frame_ptr = alloc[UnsafePointer[Scalar[DType.uint8], MutExternalOrigin]](1)
        frame_ptr[] = new_frame.unsafe_ptr().unsafe_origin_cast[MutExternalOrigin]()
        var linesize = Int(camera.pixel_width * UInt(channels))
        video.steal_frame(frame_ptr, linesize)


    def play(mut self, mut animation: Create) raises -> None:
        # TODO: Eventually support multi camera rendering
        # for camera in self.scene[].cameras: 
        # animation.begin()
        for i in range(5):
            self.render_frame(self.videos[0], self.scene[].camera, self.scene[])


    fn render(mut self, path: Path) raises:
        video_write(self.videos, path, fps=self.fps, max_duration_seconds=self.max_duration_seconds)


struct Camera(Movable):
    var pixel_height: UInt
    var pixel_width: UInt

    var position: Vector3D
    var focal_length: Float32

    def __init__(out self, pixel_height: UInt, pixel_width: UInt):
        self.pixel_height = pixel_height
        self.pixel_width = pixel_width
        self.focal_length = 1.0
        self.position = ORIGIN
        self.position[2] = 1.0


struct SquareToCircle(Scenable):
    var camera: Camera
    var background_color: SIMD[DType.uint8, 4]
    var renderer: UnsafePointer[BasicRenderer, MutExternalOrigin]

    def __init__(out self) raises:
        self.camera = Camera(320, 180)
        self.background_color = WHITE
        self.renderer = alloc[BasicRenderer](1)
        self.renderer[] = BasicRenderer(
            UnsafePointer(to=self).unsafe_origin_cast[MutExternalOrigin](),
        )

    def play(mut self, var animation: Create) raises -> None:
        print('im doing it.')
        self.renderer[].play(animation)

    def construct(mut self) raises:
        # circle = Circle()
        square = Square(BLUE_E)
        # square.flip(RIGHT)
        # square.rotate(-3 * tau / 8)
        # circle.set_fill(PINK, opacity=0.5)

        self.play(Create(square))
        # self.play(Transform(square, circle))
        # self.play(FadeOut(square))

    def render(mut self, path: Path) raises -> None:
        print('im rendering.')
        self.construct()
        self.renderer[].render(path)


def test_SquareToCircle() raises:
    var scene = SquareToCircle()
    var test_data_root = getenv("PIXI_PROJECT_ROOT")
    var root_path = join(
        test_data_root,
        "test_data/test_example/test_SquareToCircle.webm",
    )
    scene.render(root_path)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
