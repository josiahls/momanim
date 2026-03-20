from std.testing import TestSuite, assert_equal
from std.memory import memset
from std.itertools import count
from std.pathlib import Path
import std.os
from std.ffi import (
    c_uchar,
    c_int,
    c_char,
    c_long_long,
    c_float,
    c_uint,
    c_double,
    c_ulong_long,
)
from std.sys._libc_errno import ErrNo

from mav.ffmpeg.avcodec.packet import AVPacket
from mav.ffmpeg.avutil.avutil import AV_NOPTS_VALUE
from mav.ffmpeg.avcodec.codec_id import AVCodecID
from mav.ffmpeg.avutil.rational import AVRational
from mav.ffmpeg.avutil.buffer import AVBufferRef
from mav.ffmpeg.avutil.buffer_internal import AVBuffer
from mav.ffmpeg.avutil.dict import AVDictionary
from mav.ffmpeg.avcodec.avcodec import AVCodecContext
from mav.ffmpeg.avutil.frame import AVFrame
from mav.ffmpeg.avcodec.packet import (
    AVPacketSideData,
    AVPacketSideDataType,
)
from mav.ffmpeg.avcodec.defs import AV_INPUT_BUFFER_PADDING_SIZE
from mav.ffmpeg.avcodec.codec_id import AVCodecID
from mav.ffmpeg import avcodec
from mav.ffmpeg.avutil.error import AVERROR, AVERROR_EOF
from mav.ffmpeg.avformat.avformat import AVFormatContext, AVStream
from mav.ffmpeg.avformat.avio import AVIOContext
from mav.ffmpeg.avutil.frame import AVFrame
from mav.ffmpeg.avcodec.codec import AVCodec
from mav.ffmpeg.avcodec.codec_id import AVCodecID
from mav.ffmpeg.avcodec.codec_par import AVCodecParameters
from mav.ffmpeg.avcodec.packet import AVPacket
from mav.ffmpeg.swscale.swscale import SwsContext
from mav.ffmpeg.avformat.avformat import (
    AVOutputFormat,
    AVFormatContext,
    AVFMT_GLOBALHEADER,
    AVFMT_NOFILE,
)
from mav.ffmpeg.avformat import AVIO_FLAG_WRITE
from mav.ffmpeg import avformat
from mav.ffmpeg.avutil.avutil import AVMediaType
from mav.ffmpeg.avutil.samplefmt import AVSampleFormat
from mav.ffmpeg import avutil
from mav.ffmpeg.avutil.channel_layout import (
    AVChannelLayout,
    AV_CHANNEL_LAYOUT_STEREO,
)
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat
from mav.ffmpeg.swscale.swscale import SwsFlags
from mav.ffmpeg.avcodec.avcodec import AV_CODEC_FLAG_GLOBAL_HEADER
from mav.ffmpeg.avutil.error import AVERROR, AVERROR_EOF
from mav.ffmpeg.swscale import SwsFilter, SwsContext
from mav.ffmpeg import swscale
from mav.ffmpeg import swrsample
from mav.ffmpeg.swrsample import SwrContext
from std.utils import StaticTuple
from momanim.io_backends.mav.utils import convert_format
from std.logger.logger import Logger, Level, DEFAULT_LEVEL

from momanim.data_structs.video import Video

comptime STREAM_FRAME_RATE = 25
comptime STREAM_DURATION = 10.0

from momanim.constants import ColorSpace


comptime _logger = Logger[level=Level.DEBUG]()


@always_inline
def _check(ret: c_int, msg: StringLiteral) raises:
    if ret < 0:
        raise Error(msg.format(avutil.av_err2str(ret)))


def alloc_frame(
    pix_fmt: AVPixelFormat.ENUM_DTYPE,
    width: c_int,
    height: c_int,
) raises -> UnsafePointer[AVFrame, MutExternalOrigin]:
    var frame = avutil.av_frame_alloc()

    frame[].format = pix_fmt
    frame[].width = width
    frame[].height = height

    ret = avutil.av_frame_get_buffer(frame, 0)
    _check(ret, "Failed to allocate frame buffer: {}")

    return frame


struct VideoData(Copyable, Movable):
    var data: List[UnsafePointer[c_uchar, MutAnyOrigin]]
    var width: c_int
    var height: c_int
    var linesizes: List[c_int]
    var format: AVPixelFormat.ENUM_DTYPE
    var n_color_spaces: c_int
    var n_frames: c_int

    fn __init__(out self):
        self.width = 0
        self.height = 0
        self.linesizes = List[c_int]()
        self.format = AVPixelFormat.AV_PIX_FMT_NONE._value
        self.n_color_spaces = 0
        self.data = List[UnsafePointer[c_uchar, MutAnyOrigin]]()
        self.n_frames = 0


def decode_packet(
    oc: UnsafePointer[AVFormatContext, MutExternalOrigin],
    mut video_codec_ctx: UnsafePointer[AVCodecContext, MutExternalOrigin],
    packet: UnsafePointer[AVPacket, MutExternalOrigin],
    mut frame: UnsafePointer[AVFrame, MutExternalOrigin],
    mut video: Video[c_uchar.dtype],
    mut sws_ctx: UnsafePointer[
        UnsafePointer[SwsContext, MutExternalOrigin], MutExternalOrigin
    ],
) raises -> c_int:
    var ret = avcodec.avcodec_send_packet(video_codec_ctx, packet)
    if ret < 0:
        raise Error("Failed to send packet: {}".format(avutil.av_err2str(ret)))

    while ret >= 0:
        ret = avcodec.avcodec_receive_frame(video_codec_ctx, frame)
        if ret == AVERROR(ErrNo.EAGAIN.value) or ret == Int32(AVERROR_EOF):
            break
        _check(ret, "Failed to receive frame: {}")

        if frame[].format != AVPixelFormat.AV_PIX_FMT_RGB24._value:
            # TODO: Move out of the hot loop tbh.
            var tmp_frame = alloc_frame(
                pix_fmt=AVPixelFormat.AV_PIX_FMT_RGB24._value,
                width=frame[].width,
                height=frame[].height,
            )
            ret = avutil.av_frame_make_writable(tmp_frame)
            _check(ret, "Failed to make tmp frame writable: {}")

            convert_format(
                src_frame=frame,
                dst_frame=tmp_frame,
                sws_ctx=sws_ctx,
                enc=video_codec_ctx,
                src_format=frame[].format,
                dst_format=AVPixelFormat.AV_PIX_FMT_RGB24._value,
            )
            video.steal_frame(
                tmp_frame[].data.unsafe_ptr(),
                Int(tmp_frame[].linesize[0]),
            )
        else:
            video.steal_frame(
                frame[].data.unsafe_ptr(),
                Int(frame[].linesize[0]),
            )

    return ret


def video_read[
    in_buffer_size: c_int = 4096
](path: Path) raises -> List[Video[c_uchar.dtype]]:
    if not path.exists():
        raise Error("File does not exist: {}".format(path))

    _logger.info("Reading video from path: ", path)
    var packet = avcodec.av_packet_alloc()
    var frame = avutil.av_frame_alloc()
    var oc = avformat.avformat_alloc_context()
    var path_copy = String(path).copy()
    var ret = c_int(0)
    _check(
        avformat.avformat_open_input(
            s=oc, url=path_copy, fmt=None, options=None
        ),
        "Failed to open input: {}",
    )
    var videos = List[Video[c_uchar.dtype]](capacity=Int(oc[].nb_streams))
    _check(
        avformat.avformat_find_stream_info(ic=oc, options=None),
        "Failed to find stream info: {}",
    )

    var video_stream_mapping = List[Int](capacity=Int(oc[].nb_streams))
    print("Number of streams: {}".format(oc[].nb_streams))
    for i in range(oc[].nb_streams):
        var in_stream = oc[].streams[i]
        var codecpar = in_stream[].codecpar
        if codecpar[].codec_type == AVMediaType.AVMEDIA_TYPE_VIDEO._value:
            _logger.info("Found video stream: {}".format(i))
            video_stream_mapping.append(Int(i))

    for i in video_stream_mapping:
        var video_stream = oc[].streams[i]
        var video_codec_id = video_stream[].codecpar[].codec_id
        var video_codec = avcodec.avcodec_find_decoder(video_codec_id)
        var video_codec_ctx = avcodec.avcodec_alloc_context3(video_codec)
        var sws_ctx = alloc[UnsafePointer[SwsContext, MutExternalOrigin]](1)
        var video = Video[c_uchar.dtype]()

        # Copy codec parameters (including extradata/SPS/PPS for H.264) from stream.
        # Required for MP4/AVCC format; without this the decoder expects Annex B start codes.
        _check(
            avcodec.avcodec_parameters_to_context(
                video_codec_ctx, video_stream[].codecpar
            ),
            "Failed to copy codec parameters: {}",
        )

        _check(
            avcodec.avcodec_open2(video_codec_ctx, video_codec),
            "Failed to open video codec: {}",
        )
        video.w = UInt(video_stream[].codecpar[].width)
        video.h = UInt(video_stream[].codecpar[].height)
        video.color_space = ColorSpace.RGB_24
        video.ch = UInt(3)
        print("video codec ctx pix fmt: ", video_codec_ctx[].pix_fmt)
        print("video w: ", video.w)
        print("video h: ", video.h)
        frame = alloc_frame(
            pix_fmt=video_codec_ctx[].pix_fmt,
            width=c_int(video.w),
            height=c_int(video.h),
        )
        _check(
            avutil.av_frame_make_writable(frame),
            "Failed to make frame writable: {}",
        )
        while True:
            ret = avformat.av_read_frame(oc, packet)
            if ret == Int32(AVERROR_EOF):
                break
            _check(ret, "Failed to read frame: {}")

            if Int(packet[].stream_index) in video_stream_mapping:
                var pkt_ret = decode_packet(
                    oc, video_codec_ctx, packet, frame, video, sws_ctx
                )

            avcodec.av_packet_unref(packet)
            if ret < 0:
                break

        videos.append(video^)
        avcodec.avcodec_free_context(video_codec_ctx)
        # avcodec.avcodec_close(video_codec_ctx)

    avcodec.av_packet_free(packet)
    avutil.av_frame_free(frame)
    return videos^
