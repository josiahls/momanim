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

from std.testing import assert_equal

comptime _logger = Logger[level=DEFAULT_LEVEL]()


struct ImageData(Movable, Writable):
    var data: UnsafePointer[c_uchar, MutAnyOrigin]
    var width: c_int
    var height: c_int
    var format: AVPixelFormat.ENUM_DTYPE
    var n_color_spaces: c_int

    fn __init__(out self):
        self.data = UnsafePointer[c_uchar, MutAnyOrigin]()
        self.width = 0
        self.height = 0
        self.format = AVPixelFormat.AV_PIX_FMT_NONE._value
        self.n_color_spaces = 0

    fn __init__(
        out self,
        var data: UnsafePointer[c_uchar, MutAnyOrigin],
        var width: c_int,
        var height: c_int,
        var format: AVPixelFormat.ENUM_DTYPE,
        var n_color_spaces: c_int,
    ):
        self.data = data
        self.width = width
        self.height = height
        self.format = format
        self.n_color_spaces = n_color_spaces


@fieldwise_init
struct ImageInfo(Writable):
    var width: c_int
    var height: c_int
    var format: AVPixelFormat.ENUM_DTYPE
    var n_color_spaces: c_int

    fn __init__(out self):
        self.width = 0
        self.height = 0
        self.format = AVPixelFormat.AV_PIX_FMT_NONE._value
        self.n_color_spaces = 0


fn decode(
    dec_ctx: UnsafePointer[AVCodecContext, origin=MutExternalOrigin],
    frame: UnsafePointer[AVFrame, origin=MutExternalOrigin],
    pkt: UnsafePointer[AVPacket, origin=MutExternalOrigin],
    mut image_info: ImageInfo,
    mut output_buffer: List[c_uchar],
) raises:
    var ret: c_int = avcodec.avcodec_send_packet(dec_ctx, pkt)
    _logger.debug("Packet sent successfully.")

    while ret >= 0:
        ret = avcodec.avcodec_receive_frame(dec_ctx, frame)
        if ret == AVERROR(ErrNo.EAGAIN.value) or ret == Int32(AVERROR_EOF):
            break
        _logger.debug("Frame received successfully.")

        image_info.width = frame[].width
        image_info.height = frame[].height
        image_info.format = dec_ctx[].pix_fmt
        image_info.n_color_spaces = dec_ctx[].color_range

        # TODO: We should instead extend via passing in a List, that way
        # we do a chunked move operation instead of a copy which is
        # what is happening here. (dont be fooled by the ptr pass)
        output_buffer.extend(
            Span(
                ptr=frame[].data[0],
                length=Int(frame[].linesize[0] * frame[].height),
            )
        )


fn image_read[in_buffer_size: c_int = 4096](path: Path) raises -> ImageData:
    """Reads an image file.

    Parameters:
        in_buffer_size: The number of bytes to read and load into memory at one time. Default is 4096.

    """
    _logger.info("Reading image from path: ", path)

    var dict = UnsafePointer[AVDictionary, MutExternalOrigin]()
    var dict_ptr = alloc[UnsafePointer[AVDictionary, MutExternalOrigin]](1)
    dict_ptr[] = dict
    var extension = path.suffix()

    var input_buffer = InlineArray[
        c_uchar, Int(in_buffer_size + AV_INPUT_BUFFER_PADDING_SIZE)
    ](uninitialized=True)
    var output_buffer = List[c_uchar](capacity=Int(in_buffer_size))

    # Set the AV_INPUT_BUFFER_PADDING_SIZE portion of the input_buffer to zero.
    memset(
        input_buffer.unsafe_ptr() + in_buffer_size,
        0,
        Int(AV_INPUT_BUFFER_PADDING_SIZE),
    )

    var packet = avcodec.av_packet_alloc()
    var codec = avcodec.avcodec_find_decoder_by_name(extension)
    var parser = avcodec.av_parser_init(codec[].id)
    var context = avcodec.avcodec_alloc_context3(codec)
    var ret = avcodec.avcodec_open2(context, codec, dict_ptr)
    assert_equal(ret, 0)
    var frame = avutil.av_frame_alloc()
    var image_info = ImageInfo()

    with open(path, "r") as f:
        while True:
            var data = (
                input_buffer.unsafe_ptr().as_immutable()
                # NOTE: Do we need to do this?
                .unsafe_origin_cast[ImmutExternalOrigin]()
            )
            var data_size = c_int(f.read(buffer=input_buffer))
            if data_size == 0:
                break

            while data_size > 0:
                _logger.debug("Data size: ", data_size)
                var size = avcodec.av_parser_parse2(
                    parser,
                    context,
                    UnsafePointer(to=packet[].data),
                    UnsafePointer(to=packet[].size),
                    data,
                    data_size,
                    AV_NOPTS_VALUE,
                    AV_NOPTS_VALUE,
                    0,
                )

                _logger.debug("Parsed size: ", size)
                data += size
                data_size -= size

                if packet[].size > 0:
                    _logger.debug("Packet size is: ", packet[].size)
                    decode(
                        context,
                        frame,
                        packet,
                        image_info,
                        output_buffer,
                    )

    _logger.debug("Image info: ", image_info)
    _logger.debug("Output buffer: ", len(output_buffer))

    avutil.av_frame_free(frame)
    avcodec.av_packet_free(packet)
    avcodec.av_parser_close(parser)
    avcodec.avcodec_free_context(context)
    var data = output_buffer.unsafe_ptr()
    return ImageData(
        data=data,
        width=image_info.width,
        height=image_info.height,
        format=image_info.format,
        n_color_spaces=image_info.n_color_spaces,
    )


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


fn image_save(image: ImageData, path: Path) raises:
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
    print("Found codec: ", codec[])
    var context = avcodec.avcodec_alloc_context3(codec)
    context[].time_base = AVRational(num=1, den=25)
    context[].pix_fmt = image.format
    context[].width = image.width
    context[].height = image.height
    context[].color_range = image.n_color_spaces
    var packet = avcodec.av_packet_alloc()

    print("Opening codec")
    var ret = avcodec.avcodec_open2(context, codec, dict_ptr)
    assert_equal(ret, 0)

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
        frame[].data[0] = image.data.copy().unsafe_origin_cast[
            MutExternalOrigin
        ]()

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
