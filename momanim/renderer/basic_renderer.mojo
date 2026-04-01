from momanim.data_structs.video import Video
from momanim.scene.scene import Scenable
from momanim.camera.camera import Camera
from std.pathlib import Path
from momanim.constants import ColorSpace
from momanim.mobject.polygram import Square, Point
from momanim.utils.color import BLACK
from momanim.io_backends.mav.video_write import video_write


struct Create[origin: Origin](ImplicitlyDestructible, Movable):  # (Animatable):
    var obj: Pointer[Square, Self.origin]
    var run_time: Float32
    "The time the animation will run for in seconds."
    var _current_frame: UInt
    var _total_frames: UInt
    var _draw_fn: Square.draw_fn

    def __init__(out self, ref[Self.origin] obj: Square) raises:
        self.obj = Pointer(to=obj)
        self.run_time = 4
        self._current_frame = 0
        self._total_frames = 0
        self._draw_fn = self.obj[].get_draw_fn()

    def begin(mut self, fps: UInt) raises -> None:
        self._current_frame = 0
        self._total_frames = UInt(self.run_time * Float32(fps))

    def step(mut self) raises -> List[Point]:
        var max_delta: Float32 = 0.0
        if self._current_frame > 0:
            max_delta = Float32(self._current_frame) / Float32(
                self._total_frames
            )

        var L = self._draw_fn.total_length
        var total_pixels = Int(L * max_delta) + 1
        var draw_actions = List[Point](capacity=total_pixels)

        # Index-based delta avoids float drift from repeated += (missing 0.25, 0.5, … corners).
        for i in range(total_pixels):
            var delta: Float32
            if i + 1 == total_pixels:
                delta = max_delta
            else:
                delta = Float32(i) / L
            draw_actions.append(self._draw_fn(delta))

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
        camera: Camera,
        mut scene: Self.T,
        draw_actions: List[Point],
    ) raises:
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
        for ref point in draw_actions:
            var p0 = point + center_origin
            var x = Int(round(p0.x()))
            var y = Int(round(p0.y()))
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

        var frame_ptr = alloc[
            UnsafePointer[Scalar[DType.uint8], MutExternalOrigin]
        ](1)
        frame_ptr[] = new_frame^
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
            self.render_frame(
                self.videos[0],
                self.scene[].cameras()[0],
                self.scene[],
                draw_actions,
            )
        animation.end()

    fn render(mut self, path: Path) raises:
        video_write(
            self.videos,
            path,
            fps=self.fps,
            max_duration_seconds=self.max_duration_seconds,
        )
