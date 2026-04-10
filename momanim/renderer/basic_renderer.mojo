from momanim.data_structs.video import Video
from momanim.data_structs.image import Image
from momanim.scene.scene import Scenable
from momanim.camera.camera import Camera
from std.pathlib import Path
from momanim.constants import ColorSpace
from momanim.mobject.polygram import Square, Point, MObject, Style
from momanim.mobject.bezier_curve import (
    QuadBezierCurve,
    farin_rational_de_casteljau,
)
from momanim.utils.color import BLACK
from momanim.io_backends.mav.video_write import video_write
from momanim.io_backends.mav.image_write import image_write
from momanim.animation.creation import Create
from std.memory import memset
from momanim.animation.animation import Animatable
from std.math import e, pi, sqrt, round


def pdf(z: Float32) -> Float32:
    var a: Float32 = (-(z**2)) / 2
    var nom: Float32 = Float32(e) ** a
    return nom / (sqrt(2 * Float32(pi)))


def standardize(z: Float32, mean: Float32, std: Float32) -> Float32:
    return (z - mean) / std


# TODO: make this comptime
struct PaintKernel[size: Int = 3, channels: Int = 4](RegisterPassable):
    var kernel: UnsafePointer[Float32, MutExternalOrigin]

    def __init__(out self):
        self.kernel = alloc[Float32](Self.size * Self.size * Self.channels)
        comptime std = Float32(sqrt(1.0))
        comptime std_scale = 1 / std
        comptime mean: Float32 = Float32(Self.size / 2)

        comptime max_pdf = std_scale * pdf(standardize(mean, mean, std))

        comptime for i in range(Self.size):  # Row
            comptime for j in range(Self.size):  # Col
                comptime i_offset = standardize(Float32(i), mean, std)
                comptime j_offset = standardize(Float32(j), mean, std)

                comptime iw = std_scale * pdf(i_offset)
                comptime jw = std_scale * pdf(j_offset)
                comptime w = ((iw + jw) / 2) / max_pdf

                self.kernel.store(val=w, offset=i * Self.size + j)

    def store[
        width: Int
    ](
        self,
        x: Int,
        y: Int,
        value: SIMD[DType.uint8, width],
        mut ptr: UnsafePointer[Scalar[DType.uint8], MutExternalOrigin],
        row_stride: Int,
    ) raises:
        """
        Store a value at a given position in the kernel.

        Args:
            x: The x position to store the value at.
            y: The y position to store the value at.
            value: Assumed to be a RGBA value.
        """
        comptime std = Float32(sqrt(1.0))
        comptime std_scale = 1 / std
        comptime mean: Float32 = Float32(Self.size / 2)

        comptime for i in range(Self.size):  # Row
            comptime for j in range(Self.size):  # Col
                comptime i_offset = standardize(Float32(i), mean, std)
                comptime j_offset = standardize(Float32(j), mean, std)

                # TODO Need to do a more proper

                # var w = self.kernel[i * Self.size + j]

                var row_offset = (y + Int(i_offset)) * row_stride
                var col_offset = (x + Int(j_offset)) * width
                var weighted_value = value.cast[Float32.dtype]()  # * w

                ptr.store(
                    val=weighted_value.cast[DType.uint8](),
                    offset=row_offset + col_offset,
                )


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
    def background_id_mask_from_camera(
        camera: Camera,
    ) raises -> UnsafePointer[Scalar[DType.uint8], MutExternalOrigin]:
        var background_id_mask = alloc[Scalar[DType.uint8]](
            Int(camera.pixel_height) * Int(camera.pixel_width)
        )
        memset(
            background_id_mask,
            0,
            Int(camera.pixel_height) * Int(camera.pixel_width),
        )
        return background_id_mask^

    @staticmethod
    def render_frame[
        M: MObject
    ](mut video: Video[DType.uint8], mut scene: Self.T, mut obj: M,) raises:
        ref camera = scene.cameras()[0]
        var channels = len(scene.background_color())
        var new_frame = Self.frame_from_camera(camera, channels)
        # background_id_mask tracks the objects that have been currently written.
        var background_id_mask = Self.background_id_mask_from_camera(camera)
        var n_elems = (
            Int(camera.pixel_height) * Int(camera.pixel_width) * channels
        )
        # `M.CoordDType` only exists when `obj` is a concrete `MObject`, not
        # `Some[MObject]` (trait objects erase comptime associated types).
        var center_origin = Point[M.CoordDType](
            x=Scalar[M.CoordDType](Float64(camera.pixel_width) / 2.0),
            y=Scalar[M.CoordDType](Float64(camera.pixel_height) / 2.0),
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
        # One byte per pixel; must not reuse RGBA row_stride or mask indexing is wrong
        # and writes go out of bounds (can corrupt unrelated buffers / the final frame).
        var background_mask_row_stride = Int(camera.pixel_width)
        # TODO: We probably just want to dispatch on MObject types. e.g.:
        # vecotirzed is a special type, but there could be others such as groups,
        # vgroups, etc.

        var object_id: UInt8 = 1
        # TODO: Ideally we also vectorize this. Its possible we need a nicer way
        # of handling this via primitives.

        var xmin: Int = -1  # min([curve.min_x() for curve in obj.get_curves()])
        var xmax: Int = -1  # max([curve.max_x() for curve in obj.get_curves()])
        var ymin: Int = -1  # min([curve.min_y() for curve in obj.get_curves()])
        var ymax: Int = -1  # max([curve.max_y() for curve in obj.get_curves()])
        for curve in obj.get_curves():
            xmin = min(xmin, Int(curve.min_x())) if xmin != -1 else Int(
                curve.min_x()
            )
            xmax = max(xmax, Int(curve.max_x()))
            ymin = min(ymin, Int(curve.min_y())) if ymin != -1 else Int(
                curve.min_y()
            )
            ymax = max(ymax, Int(curve.max_y()))

        for i in range(obj.n_curves()):
            var curve = obj.get_curve(i)
            ref style = obj.get_style()
            # Draw really should probably be a dumb kernel.
            Self.draw[M.CoordDType](
                i,
                curve,
                center_origin,
                new_frame,
                camera,
                row_stride,
                background_mask_row_stride,
                channels,
                style,
                background_id_mask,
                object_id,
            )

        for i in range(obj.n_curves()):
            var curve = obj.get_curve(i)
            ref style = obj.get_style()
            Self.draw_fill[M.CoordDType](
                i,
                curve,
                center_origin,
                new_frame,
                camera,
                row_stride,
                background_mask_row_stride,
                channels,
                style,
                background_id_mask,
                object_id,
                xmin,
                ymin,
                xmax,
                ymax,
            )
            # TODO: Really don't want to have to do this twice...
            Self.draw[M.CoordDType](
                i,
                curve,
                center_origin,
                new_frame,
                camera,
                row_stride,
                background_mask_row_stride,
                channels,
                style,
                background_id_mask,
                object_id,
                skip_background=True,
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
    def draw[
        curve_dtype: DType
    ](
        curve_idx: Int,
        curve: QuadBezierCurve[curve_dtype],
        center_origin: Point[curve_dtype],
        mut new_frame: UnsafePointer[Scalar[DType.uint8], MutExternalOrigin],
        camera: Camera,
        row_stride: UInt,
        background_mask_row_stride: Int,
        channels: Int,
        style: Style,
        mut background_id_mask: UnsafePointer[
            Scalar[DType.uint8], MutExternalOrigin
        ],
        object_id: UInt8,
        skip_background: Bool = False,
    ) raises:
        var granularity: Float32 = 0.01
        var previous_point: Optional[Point[curve_dtype]] = None
        var kernel = PaintKernel[style.kernel_size]()
        var background_kernel = PaintKernel[style.kernel_size, channels=1]()

        for t in range(0, Int(1 / granularity)):
            # TODO: Verify, can `farin_rational_de_casteljau` be used as a gpu kernel?
            var p0 = (
                farin_rational_de_casteljau(curve, t * granularity)
                + center_origin
            )
            var x = Int(round(p0.coords[0]))
            var y = Int(round(p0.coords[1]))
            # TODO: Ideally we want to be able to do this in GPU, however
            # these if statements are not great for Warps (divergence).
            if (
                x < 0
                or y < 0
                or x >= Int(camera.pixel_width)
                or y >= Int(camera.pixel_height)
            ):
                continue

            # kernel.store(x, y, style.color_edges, new_frame, Int(row_stride))
            new_frame.store(
                val=style.color_edges.cast[DType.uint8](),
                offset=y * row_stride + x * channels,
            )
            if not skip_background:
                background_id_mask.store(
                    val=object_id,
                    offset=y * background_mask_row_stride + x,
                )
                print(
                    (
                        "background_id_mask.store(val=object_id, offset=y *"
                        " row_stride + x)"
                    ),
                    background_id_mask.load(
                        offset=y * background_mask_row_stride + x
                    ),
                    "y: ",
                    y,
                    "x: ",
                    x,
                )

    @staticmethod
    def draw_fill[
        curve_dtype: DType
    ](
        curve_idx: Int,
        curve: QuadBezierCurve[curve_dtype],
        center_origin: Point[curve_dtype],
        mut new_frame: UnsafePointer[Scalar[DType.uint8], MutExternalOrigin],
        camera: Camera,
        row_stride: UInt,
        background_mask_row_stride: Int,
        channels: Int,
        style: Style,
        mut background_id_mask: UnsafePointer[
            Scalar[DType.uint8], MutExternalOrigin
        ],
        object_id: UInt8,
        xmin: Int,
        ymin: Int,
        xmax: Int,
        ymax: Int,
    ) raises:
        var granularity: Float32 = 0.01
        var previous_point: Optional[Point[curve_dtype]] = None
        var kernel = PaintKernel[style.kernel_size]()

        if style.color_fill[3] == 0:
            # Skip if the opacity is completely transparent
            return

        # Same pixel space as `draw`: stroke uses `de_casteljau(...) + center_origin`.
        # Curve min/max are in local coordinates; without `center_origin` the loops
        # scan tiny indices (e.g. -1..1) while the mask is written at frame pixels
        # (e.g. 332), so `mask == object_id` never matches.
        var ox = Float64(center_origin.coords[0])
        var oy = Float64(center_origin.coords[1])
        var xmin_rounded = Int(round(Float64(xmin + ox))) - 5
        var xmax_rounded = Int(round(Float64(xmax + ox)))
        var ymin_rounded = Int(round(Float64(ymin + oy))) - 5
        var ymax_rounded = Int(round(Float64(ymax + oy)))

        for y in range(ymin_rounded, ymax_rounded + 1):
            if y < 0 or y >= Int(camera.pixel_height):
                continue

            var edge_count: Int = 0
            var x_edge_loc: Int = -1
            var x_col_start: Int = -1
            # print('checking y: ', y)
            for x in range(xmin_rounded, xmax_rounded + 1):
                if x < 0 or x >= Int(camera.pixel_width):
                    continue

                # print('checking x: ', x, 'background_id_mask[y * background_mask_row_stride + x]', background_id_mask[y * background_mask_row_stride + x])

                if (
                    background_id_mask[y * background_mask_row_stride + x]
                    == object_id
                ) and (x_edge_loc != x - 1):
                    edge_count += 1
                    x_edge_loc = x
                    print("edge_count: ", edge_count)
                    if edge_count % 2 != 0:
                        x_col_start = x

                if edge_count % 2 == 0 and edge_count > 0:
                    edge_count = 0
                    for fill_x in range(x_col_start + 1, x):
                        # print('drawing fill at x:', x,'y:', y, 'object_id:', object_id, 'color:', style.color_fill)
                        # kernel.store(x, y, style.color_fill, new_frame, Int(row_stride))
                        new_frame.store(
                            val=style.color_fill.cast[DType.uint8](),
                            offset=y * row_stride + fill_x * channels,
                        )

    def play(mut self, mut animation: Some[Animatable]) raises -> None:
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

    def render_image(mut self, path: Path) raises:
        image_write(
            Image[DType.uint8](
                w=self.videos[0].w,
                h=self.videos[0].h,
                ch=4,
                color_space=ColorSpace.RGBA_32,
                container=self.videos[0]._frames[-1]._data.copy(),
                line_size=self.videos[0].linesize,
            ),
            path,
        )
