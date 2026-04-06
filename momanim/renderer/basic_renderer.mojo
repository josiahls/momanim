from momanim.data_structs.video import Video
from momanim.scene.scene import Scenable
from momanim.camera.camera import Camera
from std.pathlib import Path
from momanim.constants import ColorSpace
from momanim.mobject.polygram import Square, Point
from momanim.mobject.bezier_curve import (
    QuadBezierCurve,
    farin_rational_de_casteljau,
)
from momanim.utils.color import BLACK
from momanim.io_backends.mav.video_write import video_write


struct Create[origin: Origin](ImplicitlyDestructible, Movable):  # (Animatable):
    var starting_obj: Pointer[mut=False, Square[DType.float32], Self.origin]
    var run_time: Float32
    "The time the animation will run for in seconds."
    var _current_frame: UInt
    var _total_frames: UInt

    def __init__(out self, ref[Self.origin] obj: Square[DType.float32]) raises:
        self.starting_obj = Pointer[mut=False](to=obj)
        self.run_time = 4
        self._current_frame = 0
        self._total_frames = 0

    def begin(mut self, fps: UInt) raises -> None:
        self._current_frame = 0
        self._total_frames = UInt(self.run_time * Float32(fps))

    def step(mut self) raises -> List[QuadBezierCurve[DType.float32]]:
        var max_delta: Float32 = 0.0
        if self._current_frame > 0:
            max_delta = Float32(self._current_frame) / Float32(
                self._total_frames
            )

        # var total_pixels = Int(L * max_delta) + 1
        var draw_actions = List[QuadBezierCurve[DType.float32]](capacity=3)

        var copy_obj = self.starting_obj[].copy()
        copy_obj = copy_obj.pointwise_become_partial(
            self.starting_obj[],
            a=0,
            b=max_delta,
        )
        for curve in copy_obj.curves:
            draw_actions.append(curve)

        self._current_frame += 1
        return draw_actions^

    def end(mut self) -> None:
        self._current_frame = self._total_frames

    def is_finished(self) -> Bool:
        return self._current_frame > self._total_frames


struct BasicRenderer[T: Scenable](Movable):
    var scene: UnsafePointer[Self.T, MutExternalOrigin]
    var fps: UInt
    var max_duration_seconds: Float32
    var videos: List[Video[DType.uint8]]
    var frame: UInt

    def __init__(
        out self,
        scene_ptr: UnsafePointer[Self.T, MutExternalOrigin],
        fps: UInt = 1,
        max_duration_seconds: Float32 = 4,
    ) raises:
        self.scene = scene_ptr
        self.fps = fps
        self.frame = 0  # TODO: Should this really be a field?
        self.max_duration_seconds = max_duration_seconds
        self.videos = List[Video[DType.uint8]]()
        self.videos.append(Self.video_from_camera(self.scene[].cameras()[0]))

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
    def frame_from_camera(
        camera: Camera, channels: Int
    ) raises -> UnsafePointer[Scalar[DType.uint8], MutExternalOrigin]:
        return alloc[Scalar[DType.uint8]](
            Int(camera.pixel_height) * Int(camera.pixel_width) * channels
        )

    @staticmethod
    def render_frame(
        mut video: Video[DType.uint8],
        mut scene: Self.T,
        draw_actions: List[QuadBezierCurve[DType.float32]],
    ) raises:
        ref camera = scene.cameras()[0]
        var channels = len(scene.background_color())
        var new_frame = Self.frame_from_camera(camera, channels)
        var n_elems = (
            Int(camera.pixel_height) * Int(camera.pixel_width) * channels
        )
        var center_origin = Point(
            x=Float32(camera.pixel_width / 2),
            y=Float32(camera.pixel_height / 2),
        )

        # TODO: Would be nice to vectorize this. We need to maintain max CACHE_LINE_SIZE
        # ideally though. I think we can do this easily with vectorize since it can
        # handle the cache line size and process the tail if needed.
        var pixel_num = 0
        var current_ch = 0
        while pixel_num < n_elems:
            (new_frame + pixel_num).store(
                val=scene.background_color()[pixel_num % channels]
            )
            pixel_num += 1

        var row_stride = camera.pixel_width * channels
        # TODO: Ideally we also vectorize this. Its possible we need a nicer way
        # of handling this via primitives.
        for action in draw_actions:
            Self.draw(
                action, center_origin, new_frame, camera, row_stride, channels
            )

        var frame_ptr = alloc[
            UnsafePointer[Scalar[DType.uint8], MutExternalOrigin]
        ](1)
        frame_ptr[] = new_frame^
        var linesize = Int(camera.pixel_width * UInt(channels))
        # Deep-copy: `new_frame` is freed when this function returns; without copy,
        # VideoFrame would keep a dangling pointer and every encoded frame could match.
        video.steal_frame(frame_ptr, linesize, copy=True)
        frame_ptr.free()

    @staticmethod
    def draw(
        curve: QuadBezierCurve[DType.float32],
        center_origin: Point[DType.float32],
        mut new_frame: UnsafePointer[Scalar[DType.uint8], MutExternalOrigin],
        camera: Camera,
        row_stride: UInt,
        channels: Int,
    ) raises:
        # for i, point in enumerate(curve.points):
        #     var p0 = point + center_origin
        var granularity: Float32 = 0.01
        for t in range(0, Int(1 / granularity)):
            var p0 = (
                farin_rational_de_casteljau(curve, t * granularity)
                + center_origin
            )
            var x = Int(round(p0.coords[0]))
            var y = Int(round(p0.coords[1]))
            if (
                x < 0
                or y < 0
                or x >= Int(camera.pixel_width)
                or y >= Int(camera.pixel_height)
            ):
                continue

            var offset = y * row_stride
            for ch in range(channels):
                var channel_stride = x * channels
                (new_frame + offset + channel_stride + ch).store(val=BLACK[ch])

    def play(mut self, mut animation: Create) raises -> None:
        # TODO: Eventually support multi camera rendering
        # for camera in self.scene[].cameras:
        animation.begin(self.fps)
        while not animation.is_finished():
            # animation.interpolate(1.0 / Float32(self.fps))
            var draw_actions = animation.step()
            self.render_frame(
                self.videos[0],
                self.scene[],
                draw_actions,
            )
        animation.end()

    def render(mut self, path: Path) raises:
        video_write(
            self.videos,
            path,
            fps=self.fps,
            max_duration_seconds=self.max_duration_seconds,
        )
