from std.pathlib import Path

from momanim.io_backends.mav.image_write import image_write
from momanim.pix_forge.surface import *
from momanim.pix_forge.paint import paint
from std.ffi import c_int
from momanim.io_backends.mav.image_write import image_write
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat
from mav.ffmpeg.avutil.pixfmt import AVColorRange, AVColorSpace


def convert_RGBA_F128_to_RGBA_U32[
    batch_size: Int = 64
](
    buffer: UnsafePointer[RGBA, MutExternalOrigin],
    size: Int,
    msg: StaticString,
) -> UnsafePointer[RGBA_U32, MutExternalOrigin]:
    var unroll_end = std.math.align_down(size, batch_size)
    var out_buffer = alloc[RGBA_U32](size)
    var offset: Int = 0

    def convert(a: RGBA) -> RGBA_U32:
        # NOTE: Maybe look into in detail:
        # https://30fps.net/pages/255-vs-256-division/
        return RGBA_U32((a * 255).clamp(0, 255))

    for _ in range(0, unroll_end, batch_size):
        comptime for _ in range(batch_size):
            out_buffer[offset] = convert(buffer[offset])
            offset += 1

    # Fill the remainder
    for _ in range(unroll_end, size):
        out_buffer[offset] = convert(buffer[offset])
        offset += 1
    debug_assert(out_buffer[offset] == (out_buffer + size)[], msg)
    return out_buffer


def surface_to_png(
    surface: ColorSurface, path: Path, line_alignment: Int = 16
) raises:
    # TODO: We should do a comptime check here and only cast when they mismatch.
    var buffer: UnsafePointer[UInt8, MutExternalOrigin]
    var line_size_bytes: c_int

    comptime if surface.format.size == RGBA.size and surface.format.dtype == RGBA.dtype:
        var new_buffer = convert_RGBA_F128_to_RGBA_U32(
            surface.buffer,
            surface.size,
            "error during `convert_RGBA_F128_to_RGBA_U32` convertion",
        )

        buffer = new_buffer.bitcast[UInt8]()
        line_size_bytes = c_int(surface.width * size_of[RGBA_U32]())

        # Put a blue pixel at the end:
        buffer[line_size_bytes * c_int(surface.height) - 2] = 255
        buffer[line_size_bytes * c_int(surface.height) - 4] = 0
    else:
        buffer = surface.buffer.bitcast[UInt8]()
        line_size_bytes = c_int(surface.line_size_bytes)

    image_write(
        w=c_int(surface.width),
        h=c_int(surface.height),  # Should result in half fill image
        data=buffer,
        line_size=c_int(line_size_bytes),
        from_fmt=AVPixelFormat.AV_PIX_FMT_RGBA._value,
        color_range=AVColorRange.AVCOL_RANGE_JPEG._value,
        path=path,
    )
