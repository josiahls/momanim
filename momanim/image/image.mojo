from std.ffi import c_uchar, c_char, c_int
from std.sys._libc_errno import ErrNo
from std.pathlib import Path
from std.os import abort
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat
from momanim.image.io import image_save, image_read, ImageData


@fieldwise_init
struct ImageInfo:
    var width: c_int
    var height: c_int
    var format: AVPixelFormat.ENUM_DTYPE
    var n_color_spaces: c_int

    fn __init__(out self):
        self.width = 0
        self.height = 0
        self.format = AVPixelFormat.AV_PIX_FMT_NONE._value
        self.n_color_spaces = 0


struct Image(Movable, Writable):
    var _data: UnsafePointer[c_uchar, MutAnyOrigin]

    var width: c_int
    var height: c_int
    var format: AVPixelFormat.ENUM_DTYPE
    var n_color_spaces: c_int

    fn __init__(out self, var data: List[c_uchar]):
        self._data = data.unsafe_ptr()
        self.width = 0
        self.height = 0
        self.format = AVPixelFormat.AV_PIX_FMT_NONE._value
        self.n_color_spaces = 0

    fn __init__(
        out self,
        var data: UnsafePointer[c_uchar, MutAnyOrigin],
        width: c_int,
        height: c_int,
        format: AVPixelFormat.ENUM_DTYPE,
        n_color_spaces: c_int,
    ):
        self._data = data
        self.width = width
        self.height = height
        self.format = format
        self.n_color_spaces = n_color_spaces

    @staticmethod
    fn load(path: Path) raises -> Self:
        var image_data = image_read(path)
        return Self(
            data=image_data.data,
            width=image_data.width,
            height=image_data.height,
            format=image_data.format,
            n_color_spaces=image_data.n_color_spaces,
        )

    fn save(self, path: Path) raises:
        image_save(
            ImageData(
                data=self._data.unsafe_origin_cast[MutExternalOrigin](),
                width=self.width,
                height=self.height,
                format=self.format,
                n_color_spaces=self.n_color_spaces,
            ),
            path,
        )
