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


from momanim.data_structs.image import Image
from momanim.constants import ColorSpace

comptime _logger = Logger[level=DEFAULT_LEVEL]()


fn encode(
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


fn image_save(image: Image[c_uchar.dtype], path: Path) raises:
    """Saves an image to a file.

    Args:
        image: The image to save.
        path: The path to save the image to.
    """
    _logger.info("Saving image to path: ", path)

    var dict = UnsafePointer[AVDictionary, MutExternalOrigin]()
    var dict_ptr = alloc[UnsafePointer[AVDictionary, MutExternalOrigin]](1)
    dict_ptr[] = dict
    var extension = path.suffix()

    var codec = avcodec.avcodec_find_encoder_by_name(extension)
    var context = avcodec.avcodec_alloc_context3(codec)
    context[].time_base = AVRational(num=1, den=25)
    if image.color_space == ColorSpace.RGB_24:
        context[].pix_fmt = AVPixelFormat.AV_PIX_FMT_RGB24._value
    elif image.color_space == ColorSpace.YUV_420:
        context[].pix_fmt = AVPixelFormat.AV_PIX_FMT_YUV420P._value
    else:
        raise Error("Unsupported color space: ", image.color_space)
    context[].width = c_int(image.w)
    context[].height = c_int(image.h)
    context[].color_range = c_int(image.ch)
    var packet = avcodec.av_packet_alloc()

    print("Opening codec")
    var ret = avcodec.avcodec_open2(context, codec, dict_ptr)
    if ret < 0:
        raise Error("Failed to open codec: ", ret)

    print("Opened codec")
    var frame = avutil.av_frame_alloc()
    print("Allocated frame")
    frame[].format = context[].pix_fmt
    frame[].width = context[].width
    frame[].height = context[].height
    frame[].color_range = context[].color_range

    print("Getting frame buffer")
    ret = avutil.av_frame_get_buffer(frame, 0)
    if ret < 0:
        raise Error("Failed to allocate frame buffer: ", ret)

    with open(path, "w") as f:
        var i = c_int(0)
        # while True:
        print("Making frame writable")
        ret = avutil.av_frame_make_writable(frame)
        if ret < 0:
            raise Error("Failed to make frame writable: ", ret)

        # TODO: Remove the copy. We should be able to do a take or something.
        # Also we really need to factor in whether the pointer is
        # even the correct format.
        frame[].data[0] = image._data.ptr

        frame[].pts = c_long_long(i)
        i += 1

        encode(
            context,
            frame,
            packet,
            f,
        )

        encode(
            context,
            UnsafePointer[AVFrame, origin=MutExternalOrigin](),
            packet,
            f,
        )

        avutil.av_frame_free(frame)
        avcodec.av_packet_free(packet)
        avcodec.avcodec_free_context(context)
