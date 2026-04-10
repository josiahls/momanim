from std.ffi import c_uchar, c_char, c_int, c_long_long
from std.sys._libc_errno import ErrNo
from std.pathlib import Path
from mav.ffmpeg.avcodec.packet import AVPacket
from mav.ffmpeg import avformat
from mav.ffmpeg import avcodec
from mav.ffmpeg import avutil
from mav.ffmpeg import swscale
from mav.ffmpeg import swrsample
from mav.ffmpeg.avformat import AVFormatContext
from mav.ffmpeg.avutil.dict import AVDictionary
from mav.ffmpeg.avcodec.defs import AV_INPUT_BUFFER_PADDING_SIZE
from mav.ffmpeg.avutil.avutil import AV_NOPTS_VALUE
from std.memory import memset
from mav.ffmpeg.avcodec.avcodec import AVCodecContext
from mav.ffmpeg.avutil.frame import AVFrame
from mav.ffmpeg.avutil.error import AVERROR, AVERROR_EOF
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat
from mav.ffmpeg.avutil.rational import AVRational
from std.logger.logger import Logger, Level, DEFAULT_LEVEL
from mav.ffmpeg.avutil.pixfmt import AVColorRange, AVColorSpace
from mav.ffmpeg.swscale.swscale import SwsContext
from momanim.io_backends.mav.utils import convert_format

from momanim.data_structs.image import Image
from momanim.constants import ColorSpace

comptime _logger = Logger[level=DEFAULT_LEVEL]()


@always_inline
def _check(ret: c_int, msg: StringLiteral) raises:
    if ret < 0:
        raise Error(msg.format(avutil.av_err2str(ret)))


def alloc_frame(
    pix_fmt: AVPixelFormat.ENUM_DTYPE,
    width: c_int,
    height: c_int,
    colorspace: c_int,
) raises -> UnsafePointer[AVFrame, MutExternalOrigin]:
    var frame = avutil.av_frame_alloc()

    frame[].format = pix_fmt
    frame[].width = width
    frame[].height = height
    frame[].colorspace = colorspace

    _check(
        avutil.av_frame_get_buffer(frame, 0),
        "Failed to allocate frame buffer: {}",
    )

    return frame


def alloc_frame(
    codec_ctx: UnsafePointer[AVCodecContext, MutExternalOrigin]
) raises -> UnsafePointer[AVFrame, MutExternalOrigin]:
    return alloc_frame(
        codec_ctx[].pix_fmt,
        codec_ctx[].width,
        codec_ctx[].height,
        codec_ctx[].color_space,
    )


def encode(
    enc_ctx: UnsafePointer[AVCodecContext, origin=MutExternalOrigin],
    frame: UnsafePointer[AVFrame, origin=MutExternalOrigin],
    pkt: UnsafePointer[AVPacket, origin=MutExternalOrigin],
    mut outfile: FileHandle,
) raises:
    var ret = avcodec.avcodec_send_frame(enc_ctx, frame)
    if ret < 0:
        raise Error("Failed to send frame for encoding: ", ret)

    while ret >= 0:
        ret = avcodec.avcodec_receive_packet(enc_ctx, pkt)
        if ret == AVERROR(ErrNo.EAGAIN.value) or ret == Int32(AVERROR_EOF):
            break

        outfile.write_bytes(
            Span(
                ptr=pkt[].data,
                length=Int(pkt[].size),
            )
        )
        avcodec.av_packet_unref(pkt)


def get_pix_fmt_from_extension(
    extension: String,
) raises -> AVPixelFormat.ENUM_DTYPE:
    if extension == ".png":
        return AVPixelFormat.AV_PIX_FMT_RGB24._value
    elif extension == ".jpg" or extension == ".jpeg":
        return AVPixelFormat.AV_PIX_FMT_YUV420P._value
    else:
        raise Error("Unsupported extension: ", extension)


def image_write(image: Image[c_uchar.dtype], path: Path) raises:
    """Saves an image to a file.

    Args:
        image: The image to save.
        path: The path to save the image to.
    """
    _logger.info("Saving image to path: ", path)

    var dict = UnsafePointer[AVDictionary, MutExternalOrigin]()
    var dict_ptr = alloc[UnsafePointer[AVDictionary, MutExternalOrigin]](1)
    dict_ptr[] = dict
    var suffix = path.suffix()
    var codec_name = suffix
    if suffix == ".jpeg" or suffix == ".jpg":
        codec_name = "mjpeg"

    var sws_ctx_ptr = UnsafePointer[SwsContext, MutExternalOrigin]()
    var sws_ctx = alloc[type_of(sws_ctx_ptr)](1)
    sws_ctx[] = sws_ctx_ptr
    var codec = avcodec.avcodec_find_encoder_by_name(codec_name)
    var context = avcodec.avcodec_alloc_context3(codec)
    context[].time_base = AVRational(num=1, den=25)
    var from_fmt = AVPixelFormat.AV_PIX_FMT_NONE._value
    if image.color_space == ColorSpace.RGB_24:
        from_fmt = AVPixelFormat.AV_PIX_FMT_RGB24._value
    elif image.color_space == ColorSpace.RGBA_32:
        from_fmt = AVPixelFormat.AV_PIX_FMT_RGBA._value
    elif image.color_space == ColorSpace.YUV_420P:
        from_fmt = AVPixelFormat.AV_PIX_FMT_YUV420P._value
    else:
        raise Error("Unsupported color space: ", image.color_space)
    context[].width = c_int(image.w)
    context[].height = c_int(image.h)
    if "color_range" in image.io_backend_opaque_params:
        context[].color_range = image.io_backend_opaque_params[
            "color_range"
        ].bitcast[c_int]()[]
    else:
        print("No color range found, using default")
        context[].color_range = AVColorRange.AVCOL_RANGE_JPEG._value
    var packet = avcodec.av_packet_alloc()

    context[].pix_fmt = get_pix_fmt_from_extension(suffix)

    print("Opening codec")
    _check(
        avcodec.avcodec_open2(context, codec, dict_ptr),
        "Failed to open codec: {}",
    )

    # Source: packed pixels from `image` (e.g. RGBA). Do not call av_frame_get_buffer;
    # FFmpeg must not own this memory — it lives on `Image`.
    var src_frame = avutil.av_frame_alloc()
    src_frame[].format = from_fmt
    src_frame[].width = c_int(image.w)
    src_frame[].height = c_int(image.h)
    src_frame[].colorspace = AVColorSpace.AVCOL_SPC_RGB._value
    src_frame[].color_range = AVColorRange.AVCOL_RANGE_JPEG._value
    src_frame[].data[0] = image._data.ptr
    src_frame[].linesize[0] = c_int(image.line_size)
    src_frame[].pts = 0

    # Destination: codec-native layout (RGB24 for PNG, YUV420P for MJPEG).
    var dst_frame = alloc_frame(context)
    _check(
        avutil.av_frame_make_writable(dst_frame),
        "Failed to make frame writable: {}",
    )
    convert_format(
        src_frame=src_frame,
        dst_frame=dst_frame,
        sws_ctx=sws_ctx,
        enc=context,
        src_format=from_fmt,
        dst_format=context[].pix_fmt,
    )

    with open(path, "w") as f:
        encode(
            context,
            dst_frame,
            packet,
            f,
        )

        encode(
            context,
            UnsafePointer[AVFrame, origin=MutExternalOrigin](),
            packet,
            f,
        )

        swscale.sws_freeContext(sws_ctx[])

        var src_ptr = alloc[UnsafePointer[AVFrame, MutExternalOrigin]](1)
        src_ptr[] = src_frame
        avutil.av_frame_free(src_ptr)
        src_ptr.free()
        var frame_ptr = alloc[UnsafePointer[AVFrame, MutExternalOrigin]](1)
        frame_ptr[] = dst_frame
        avutil.av_frame_free(frame_ptr)
        frame_ptr.free()
        var pkt_ptr = alloc[UnsafePointer[AVPacket, MutExternalOrigin]](1)
        pkt_ptr[] = packet
        avcodec.av_packet_free(pkt_ptr)
        pkt_ptr.free()
        var ctx_ptr = alloc[UnsafePointer[AVCodecContext, MutExternalOrigin]](1)
        ctx_ptr[] = context
        avcodec.avcodec_free_context(ctx_ptr)
        ctx_ptr.free()
