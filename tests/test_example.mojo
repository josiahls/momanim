from std.testing import TestSuite, assert_equal
from momanim.constants import ColorSpace, RIGHT, ORIGIN
from std.math import tau, sqrt
from std.os import getenv
from std.pathlib import Path
from std.os.path import join
from momanim.scene.scene import Scenable
from momanim.mobject.polygram import Square
from momanim.data_structs.video import Video
from momanim.io_backends.mav.video_write import video_write
from momanim.typing import Vector3D
from std.utils.variant import Variant
import numojo as nm
# from momanim.animation.animation import Animatable
# from momanim.animation.creation import Create
# from momanim.renderer.basic_renderer import BasicRenderer
from momanim.utils.color import rgb, rgba, WHITE, BLACK, BLUE_E




struct Point(TrivialRegisterPassable, Movable, Writable):
    var x: Float32
    var y: Float32
    var z: Float32

    fn __init__(out self, x: Float32, y: Float32, z: Float32):
        self.x = x
        self.y = y
        self.z = z

    fn __init__(out self, x: Float32, y: Float32):
        self.x = x
        self.y = y
        self.z = 1.0

    fn __sub__(self, other: Point) -> Point:
        return Point(self.x - other.x, self.y - other.y, self.z - other.z)
    
    fn __matmul__(self, other: Point) -> Float32:
        return self.x * other.x + self.y * other.y + self.z * other.z

    fn __mul__(self, other: Float32) -> Point:
        return Point(self.x * other, self.y * other, self.z * other)

    fn __add__(self, other: Point) -> Point:
        return Point(self.x + other.x, self.y + other.y, self.z + other.z)

    fn __truediv__(self, other: Float32) -> Point:
        return Point(self.x / other, self.y / other, self.z / other)


struct Line(Movable, Copyable, Sized, Writable):
    var p0: Point
    var p1: Point

    fn __init__(out self, p0: Point, p1: Point):
        self.p0 = p0
        self.p1 = p1

    fn __len__(self) -> Int:
        return Int(
            Int(sqrt((self.p0 - self.p1) @ (self.p0 - self.p1))),
        )

comptime DrawActions = Variant[Line]



struct CreateLine(Copyable, ImplicitlyDestructible, Writable): #(Animatable):
    var segment: Line
    var run_time: Float32
    "The time the animation will run for in seconds."
    var _current_frame: UInt
    var _total_frames: UInt

    def __init__(out self, segment: Line, run_time: Float32) raises:
        self.segment = segment.copy()
        self.run_time = run_time
        self._current_frame = 0
        self._total_frames = 0

    def begin(mut self, fps: UInt) -> None:
        self._current_frame = 0
        self._total_frames = UInt(self.run_time * Float32(fps))
        if self._total_frames == 0:
            # TODO: Probably warn about this idk.
            self._total_frames = 1

    def step(mut self) raises -> List[Line]:
        if self.is_finished():
            return List[Line]([self.segment.copy()])

        self._current_frame += 1
        var draw_actions = List[Line]()
        var t = Float32(self._current_frame) / Float32(self._total_frames) 
        var mag_vec = self.segment.p1 - self.segment.p0
        var line = Line(self.segment.p0, self.segment.p0 + mag_vec * t)

        draw_actions.append(line^)
        return draw_actions^

    def end(mut self) -> None:
        self._current_frame = self._total_frames

    def is_finished(self) -> Bool:
        return self._current_frame >= self._total_frames




struct Create[origin: Origin](Movable, ImplicitlyDestructible): #(Animatable):
    var obj: Pointer[Square, Self.origin]
    var run_time: Float32
    "The time the animation will run for in seconds."
    var _current_frame: UInt
    var _total_frames: UInt
    var _create_lines: List[CreateLine]

    def __init__(out self, ref[Self.origin] obj: Square) raises:
        self.obj = Pointer(to=obj)
        self.run_time = 4
        self._current_frame = 0
        self._total_frames = 0
        self._create_lines = List[CreateLine]()

    def begin(mut self, fps: UInt) raises -> None:
        self._current_frame = 0
        self._total_frames = UInt(self.run_time * Float32(fps))
        var lines = List[Line]()
        var total_length: Float32 = 0.0
        for i in range(len(self.obj[].vertices) -1):
            var p0 = Point(self.obj[].vertices[i].item(0), self.obj[].vertices[i].item(1))
            var p1 = Point(self.obj[].vertices[i + 1].item(0), self.obj[].vertices[i + 1].item(1))
            # print('begining: p0: ', p0, 'p1: ', p1)
            var line = Line(p0, p1)
            total_length += Float32(len(line))
            lines.append(line^)

            if i == len(self.obj[].vertices) - 2:
                p0 = p1.copy()
                p1 = Point(self.obj[].vertices[0].item(0), self.obj[].vertices[0].item(1))
                # print('begining: p0: ', p0, 'p1: ', p1)
                line = Line(p0, p1)
                total_length += Float32(len(line))
                lines.append(line^)

        for ref line in lines:
            var sub_run_time = (Float32(len(line)) / total_length) * self.run_time
            print('sub_run_time: ', sub_run_time, 'line: ', line)
            var sub_action = CreateLine(line.copy(), sub_run_time)
            sub_action.begin(fps)
            self._create_lines.append(sub_action^)


    def step(mut self) raises -> List[Line]:
        self._current_frame += 1
        var draw_actions = List[Line]()
        for ref create_line in self._create_lines:
            var finished = create_line.is_finished()
            var sub_draw_actions = create_line.step()
            draw_actions.extend(sub_draw_actions^)
            if not finished:
                break

        return draw_actions^

    def end(mut self) -> None:
        self._current_frame = self._total_frames

    def is_finished(self) -> Bool:
        return self._current_frame >= self._total_frames


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
        self.max_duration_seconds = 4
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
                Int(camera.pixel_height),
                Int(camera.pixel_width),
                channels,
            )
        )

    @staticmethod
    def render_frame(mut video: Video[DType.uint8], camera: Camera, mut scene: SquareToCircle, draw_actions: List[Line]) raises:
        var channels = len(scene.background_color)
        var new_frame = Self.frame_from_camera(camera, channels)
        var center_origin = Point(x=Float32(camera.pixel_width / 2), y=Float32(camera.pixel_height / 2))
        for ch in range(channels):
            # TODO: NuMojo doesn't support views. A copy is happening here.
            # once they support views better we have to revisit this since these
            # copies are expensive.
            ref array = new_frame[
                nm.Slice(0, Int(camera.pixel_height)),
                nm.Slice(0, Int(camera.pixel_width)),
                ch
            ]

            array.fill(scene.background_color[ch])

            new_frame[
                nm.Slice(0, Int(camera.pixel_height)),
                nm.Slice(0, Int(camera.pixel_width)),
                ch
            ] = array

        for ref line in draw_actions:
            var p0 = line.p0 + center_origin
            var p1 = line.p1 + center_origin
            var mag_vec = p1 - p0
            var t: Float32 = 0.0
            while t < 1.0:
                var p = p0 + mag_vec * t
                var x = Int(p.x)
                var y = Int(p.y)
                for ch in range(channels):
                    new_frame.itemset([Int(y), Int(x), Int(ch)], BLACK[ch])
                t += 0.01

        var frame_ptr = alloc[UnsafePointer[Scalar[DType.uint8], MutExternalOrigin]](1)
        frame_ptr[] = new_frame.unsafe_ptr().unsafe_origin_cast[MutExternalOrigin]()
        var linesize = Int(camera.pixel_width * UInt(channels))
        # Deep-copy: `new_frame` is freed when this function returns; without copy,
        # VideoFrame would keep a dangling pointer and every encoded frame could match.
        video.steal_frame(frame_ptr, linesize, copy=True)
        frame_ptr.free()


    def play(mut self, mut animation: Create) raises -> None:
        # TODO: Eventually support multi camera rendering
        # for camera in self.scene[].cameras: 
        animation.begin(self.fps)
        while not animation.is_finished():
            # animation.interpolate(1.0 / Float32(self.fps))
            var draw_actions = animation.step()
            self.render_frame(self.videos[0], self.scene[].camera, self.scene[], draw_actions)
        animation.end()


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
