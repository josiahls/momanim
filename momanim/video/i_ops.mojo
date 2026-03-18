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
from momanim.image.utils import convert_format
from std.logger.logger import Logger, Level, DEFAULT_LEVEL


comptime STREAM_FRAME_RATE = 25
comptime STREAM_DURATION = 10.0
comptime STREAM_PIX_FMT = AVPixelFormat.AV_PIX_FMT_YUV420P._value

comptime SCALE_FLAGS = SwsFlags.SWS_BICUBIC


comptime _logger = Logger[level=Level.DEBUG]()


def alloc_frame(
    pix_fmt: AVPixelFormat.ENUM_DTYPE,
    width: c_int,
    height: c_int,
    colorspace: c_int,
) raises -> UnsafePointer[AVFrame, MutExternalOrigin]:
    # var frame = alloc[AVFrame](1)

    var frame = avutil.av_frame_alloc()

    frame[].format = pix_fmt
    frame[].width = width
    frame[].height = height
    frame[].colorspace = colorspace

    ret = avutil.av_frame_get_buffer(frame, 0)
    if ret < 0:
        std.os.abort("Failed to allocate frame buffer")

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


struct DecoderContext(Copyable, Movable):
    var sws_ctx: UnsafePointer[
        UnsafePointer[SwsContext, MutExternalOrigin], MutExternalOrigin
    ]

    fn __init__(out self) raises:
        var sws_ctx_ptr = UnsafePointer[SwsContext, MutExternalOrigin]()
        self.sws_ctx = alloc[type_of(sws_ctx_ptr)](1)
        self.sws_ctx[] = sws_ctx_ptr


def decode_packet(
    oc: UnsafePointer[AVFormatContext, MutExternalOrigin],
    mut video_codec_ctx: UnsafePointer[AVCodecContext, MutExternalOrigin],
    packet: UnsafePointer[AVPacket, MutExternalOrigin],
    mut frame: UnsafePointer[AVFrame, MutExternalOrigin],
    mut video_data: VideoData,
    mut decoder_context: DecoderContext,
) raises -> c_int:
    var ret = avcodec.avcodec_send_packet(video_codec_ctx, packet)
    if ret < 0:
        raise Error("Failed to send packet: {}".format(avutil.av_err2str(ret)))

    while ret >= 0:
        ret = avcodec.avcodec_receive_frame(video_codec_ctx, frame)
        if ret == AVERROR(ErrNo.EAGAIN.value) or ret == Int32(AVERROR_EOF):
            break
        elif ret < 0:
            raise Error(
                "Failed to receive frame: {}".format(avutil.av_err2str(ret))
            )

        var tmp_frame = avutil.av_frame_alloc()
        print("converting format")
        convert_format(
            frame=frame,
            tmp_frame=tmp_frame,
            sws_ctx=decoder_context.sws_ctx,
            enc=video_codec_ctx,
            src_format=frame[].format,
            dst_format=video_data.format,
        )
        print("converted format")

        video_data.n_color_spaces = frame[].colorspace
        var total_size = c_int(0)
        for c in range(video_data.n_color_spaces):
            total_size += frame[].linesize[c] * frame[].height

        var ptr = alloc[c_uchar](Int(total_size))
        for c in range(video_data.n_color_spaces):
            # TODO: There's a more efficient way of doing this.
            ptr[] = frame[].data[c][].copy()
            ptr += frame[].linesize[c] * frame[].height
        video_data.data.append(ptr)
        video_data.width = frame[].width
        video_data.height = frame[].height
        for c in range(video_data.n_color_spaces):
            video_data.linesizes.append(frame[].linesize[c])
        video_data.format = frame[].format
        video_data.n_frames += 1
        print("writing frame number: ", video_data.n_frames)

    return ret


def video_read[
    in_buffer_size: c_int = 4096
](path: Path) raises -> List[VideoData]:
    if not path.exists():
        raise Error("File does not exist: {}".format(path))

    _logger.info("Reading video from path: ", path)
    var packet = avcodec.av_packet_alloc()
    var frame = avutil.av_frame_alloc()
    var oc = avformat.avformat_alloc_context()
    var output_buffer = List[c_uchar](capacity=Int(in_buffer_size))
    var path_copy = String(path).copy()
    var ret = avformat.avformat_open_input(
        s=oc, url=path_copy, fmt=None, options=None
    )
    var video_datas = List[VideoData](capacity=Int(oc[].nb_streams))
    if ret < 0:
        raise Error("Failed to open input: {}".format(ret))
    ret = avformat.avformat_find_stream_info(ic=oc, options=None)
    if ret < 0:
        raise Error("Failed to find stream info: {}".format(ret))

    var video_stream_mapping = List[Int](capacity=Int(oc[].nb_streams))
    print("Number of streams: {}".format(oc[].nb_streams))
    for i in range(oc[].nb_streams):
        var in_stream = oc[].streams[i]
        var codecpar = in_stream[].codecpar
        if codecpar[].codec_type == AVMediaType.AVMEDIA_TYPE_VIDEO._value:
            _logger.info("Found video stream: {}".format(i))
            video_stream_mapping.append(Int(i))

    for i in video_stream_mapping:
        print("decoding stream: ", i)
        var video_stream = oc[].streams[i]
        var video_codec_id = video_stream[].codecpar[].codec_id
        var video_codec = avcodec.avcodec_find_decoder(video_codec_id)
        var video_codec_ctx = avcodec.avcodec_alloc_context3(video_codec)
        var video_data = VideoData()
        var decoder_context = DecoderContext()
        video_datas.append(video_data^)
        # Copy codec parameters (including extradata/SPS/PPS for H.264) from stream.
        # Required for MP4/AVCC format; without this the decoder expects Annex B start codes.
        ret = avcodec.avcodec_parameters_to_context(
            video_codec_ctx, video_stream[].codecpar
        )
        if ret < 0:
            raise Error(
                "Failed to copy codec parameters: {}".format(
                    avutil.av_err2str(ret)
                )
            )
        ret = avcodec.avcodec_open2(video_codec_ctx, video_codec)
        if ret < 0:
            raise Error("Failed to open video codec: {}".format(ret))
        while True:
            ret = avformat.av_read_frame(oc, packet)
            if ret < 0:
                if ret == Int32(AVERROR_EOF):
                    break
                raise Error(
                    "Failed to read frame: {}".format(avutil.av_err2str(ret))
                )

            if Int(packet[].stream_index) in video_stream_mapping:
                print("decoding packet")
                var pkt_ret = decode_packet(
                    oc,
                    video_codec_ctx,
                    packet,
                    frame,
                    video_datas[-1],
                    decoder_context,
                )

            avcodec.av_packet_unref(packet)
            if ret < 0:
                break

        avcodec.avcodec_free_context(video_codec_ctx)
        print("freed video codec context")
        # avcodec.avcodec_close(video_codec_ctx)

    avcodec.av_packet_free(packet)
    avutil.av_frame_free(frame)
    print("done reading video")
    return video_datas^
