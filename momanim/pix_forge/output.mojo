from std.pathlib import Path

from momanim.io_backends.mav.image_write import image_write
from momanim.pix_forge.surface import *
from momanim.pix_forge.paint import paint
from std.ffi import c_int
from momanim.io_backends.mav.image_write import image_write
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat
from mav.ffmpeg.avutil.pixfmt import AVColorRange, AVColorSpace


def surface_to_png(
    surface: ColorSurface, path: Path, line_alignment: Int = 16
) raises:
    # TODO: We should do a comptime check here and only cast when they mismatch.
    var buffer = surface.buffer.bitcast[UInt8]()
    var line_size_bytes = c_int(surface.line_size_bytes)

    buffer[line_size_bytes * c_int(surface.height) - 2] = 255
    buffer[line_size_bytes * c_int(surface.height) - 4] = 0

    image_write(
        w=c_int(surface.width),
        h=c_int(surface.height),  # Should result in half fill image
        data=buffer,
        line_size=c_int(line_size_bytes),
        from_fmt=AVPixelFormat.AV_PIX_FMT_RGBA._value,
        color_range=AVColorRange.AVCOL_RANGE_JPEG._value,
        path=path,
    )
