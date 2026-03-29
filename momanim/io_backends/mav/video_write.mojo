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
from std.logger.logger import Logger, Level, DEFAULT_LEVEL
from momanim.constants import ColorSpace
from momanim.io_backends.mav.utils import convert_format


comptime STREAM_FRAME_RATE = 25
comptime STREAM_DURATION: Float32 = 10.0
comptime STREAM_PIX_FMT = AVPixelFormat.AV_PIX_FMT_YUV420P._value

comptime SCALE_FLAGS = SwsFlags.SWS_BICUBIC


from momanim.data_structs.video import Video

comptime _logger = Logger[level=Level.DEBUG]()


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
    codec: UnsafePointer[AVCodecContext, MutExternalOrigin]
) raises -> UnsafePointer[AVFrame, MutExternalOrigin]:
    return alloc_frame(
        codec[].pix_fmt, codec[].width, codec[].height, codec[].color_range
    )


@always_inline
def _check(ret: c_int, msg: StringLiteral) raises:
    if ret < 0:
        raise Error(msg.format(avutil.av_err2str(ret)))


def open_video(
    oc: UnsafePointer[AVFormatContext, MutExternalOrigin],
    mut ost: OutputStream,
    opt_arg: UnsafePointer[AVDictionary, ImmutExternalOrigin],
) raises:
    var ret: c_int = 0

    _check(
        avcodec.avcodec_open2(ost.enc, ost.codec), "Failed to open codec: {}"
    )

    ost.frame = alloc_frame(ost.enc)
    if not ost.frame:
        std.os.abort("Failed to allocate video frame")

    ost.conversion_frame = alloc_frame(ost.enc)

    _check(
        avcodec.avcodec_parameters_from_context(ost.st[].codecpar, ost.enc),
        "Failed to copy the stream parameters: {}",
    )


struct OutputStream(Copyable, Movable):
    var st: UnsafePointer[AVStream, origin=MutExternalOrigin]
    var codec: UnsafePointer[AVCodec, origin=ImmutExternalOrigin]
    var enc: UnsafePointer[AVCodecContext, origin=MutExternalOrigin]
    var next_pts: c_long_long
    var samples_count: c_int
    var frame: UnsafePointer[AVFrame, origin=MutExternalOrigin]
    var conversion_frame: UnsafePointer[AVFrame, origin=MutExternalOrigin]
    "Used for storing mid-conversion frames."
    var pkt: UnsafePointer[AVPacket, origin=MutExternalOrigin]
    var sws_ctx: UnsafePointer[
        UnsafePointer[SwsContext, origin=MutExternalOrigin],
        origin=MutExternalOrigin,
    ]
    var swr_ctx: UnsafePointer[SwrContext, origin=MutExternalOrigin]

    fn __init__(out self) raises:
        self.st = UnsafePointer[AVStream, MutExternalOrigin]()
        self.codec = UnsafePointer[AVCodec, MutExternalOrigin]()
        self.enc = UnsafePointer[AVCodecContext, MutExternalOrigin]()
        self.next_pts = c_long_long(0)
        self.samples_count = c_int(0)
        self.frame = UnsafePointer[AVFrame, MutExternalOrigin]()
        self.conversion_frame = UnsafePointer[AVFrame, MutExternalOrigin]()
        self.pkt = UnsafePointer[AVPacket, MutExternalOrigin]()
        var sws_ctx_ptr = UnsafePointer[SwsContext, MutExternalOrigin]()
        self.sws_ctx = alloc[type_of(sws_ctx_ptr)](1)
        self.sws_ctx[] = sws_ctx_ptr
        self.swr_ctx = UnsafePointer[SwrContext, MutExternalOrigin]()

    fn __del__(deinit self):
        if self.frame:
            var ptr = alloc[UnsafePointer[AVFrame, MutExternalOrigin]](1)
            ptr[] = self.frame
            avutil.av_frame_free(ptr)
            ptr.free()
        if self.conversion_frame:
            var ptr = alloc[UnsafePointer[AVFrame, MutExternalOrigin]](1)
            ptr[] = self.conversion_frame
            avutil.av_frame_free(ptr)
            ptr.free()
        if self.pkt:
            var ptr = alloc[UnsafePointer[AVPacket, MutExternalOrigin]](1)
            ptr[] = self.pkt
            avcodec.av_packet_free(ptr)
            ptr.free()
        if self.enc:
            var ptr = alloc[UnsafePointer[AVCodecContext, MutExternalOrigin]](1)
            ptr[] = self.enc
            avcodec.avcodec_free_context(ptr)
            ptr.free()
        if self.sws_ctx:
            if self.sws_ctx[]:
                swscale.sws_freeContext(self.sws_ctx[])
            self.sws_ctx.free()


def add_stream(
    oc: UnsafePointer[AVFormatContext, MutExternalOrigin],
    video: Video,
    fps: UInt,
) raises -> OutputStream:
    var ost = OutputStream()

    ost.codec = avcodec.avcodec_find_encoder(oc[].oformat[].video_codec)
    if not ost.codec:
        raise Error("Failed to find encoder")

    ost.pkt = avcodec.av_packet_alloc()
    if not ost.pkt:
        raise Error("Failed to allocate AVPacket")

    ost.st = avformat.avformat_new_stream(
        oc,
        # Add a null pointer.
        UnsafePointer[AVCodec, ImmutExternalOrigin](),
    )
    if not ost.st:
        raise Error("Failed to allocate stream")

    ost.st[].id = c_int(oc[].nb_streams - 1)

    ost.enc = avcodec.avcodec_alloc_context3(ost.codec)
    if not ost.enc:
        raise Error("Failed to allocate encoding context")

    ref codec_type = ost.codec[].type
    if codec_type == AVMediaType.AVMEDIA_TYPE_AUDIO._value:
        if not ost.codec[].sample_fmts:
            ost.enc[].sample_fmt = AVSampleFormat.AV_SAMPLE_FMT_FLTP._value
        else:
            # FIXME: Note that sample_fmts is deprecated and we should be using
            # avcodec_get_supported_config
            ost.enc[].sample_fmt = ost.codec[].sample_fmts[]
        ost.enc[].bit_rate = 64000
        ost.enc[].sample_rate = 44100
        if ost.codec[].supported_samplerates:
            ost.enc[].sample_rate = ost.codec[].supported_samplerates[]
            for i in count():
                if not ost.codec[].supported_samplerates[i]:
                    break
                if ost.codec[].supported_samplerates[i] == 44100:
                    ost.enc[].sample_rate = 44100

        var layout = alloc[AVChannelLayout](1)
        layout[] = AV_CHANNEL_LAYOUT_STEREO
        var dst = UnsafePointer(to=ost.enc[].ch_layout)
        _check(
            avutil.av_channel_layout_copy(dst, layout),
            "Failed to copy channel layout: {}",
        )
        ost.st[].time_base = AVRational(num=1, den=ost.enc[].sample_rate)

    elif codec_type == AVMediaType.AVMEDIA_TYPE_VIDEO._value:
        ost.enc[].codec_id = oc[].oformat[].video_codec
        ost.enc[].bit_rate = 400000
        # Resolution must be multople of two
        ost.enc[].width = c_int(video.w)
        ost.enc[].height = c_int(video.h)
        # Timebase: This is the fundamental unit of time (in seconds) in terms
        # of which frame timestamps are represented. For fixed-gps content
        # timebase should be 1/framerate and timestamp increments should be identical
        # to 1.
        ost.st[].time_base = AVRational(num=1, den=c_int(fps))
        ost.enc[].time_base = ost.st[].time_base

        ost.enc[].gop_size = (
            12  # Emit one intra frame every twelve frames at most
        )
        # if video.color_space == ColorSpace.RGBA_32:
        #     c[].pix_fmt = AVPixelFormat.AV_PIX_FMT_RGB24._value
        # elif video.color_space == ColorSpace.YUV_420P:
        # TODO: Need to detect and dispatch to the correct pix_fmt for a given format.
        ost.enc[].pix_fmt = AVPixelFormat.AV_PIX_FMT_YUV420P._value
        # else:
        #     raise Error("Unsupported color space: {}".format(video.color_space))
        if ost.enc[].codec_id == AVCodecID.AV_CODEC_ID_MPEG2VIDEO._value:
            # Just for testing, we also add B-frames
            ost.enc[].max_b_frames = 2

        if ost.enc[].codec_id == AVCodecID.AV_CODEC_ID_MPEG1VIDEO._value:
            # Needed to avoid using macroblocks in which some coeffs overflow.
            # This does not happen with normal video, it just happens here as
            # the motion of the chroma plane does not match the luma plane.
            ost.enc[].mb_decision = 2

    if oc[].oformat[].flags & AVFMT_GLOBALHEADER:
        ost.enc[].flags |= AV_CODEC_FLAG_GLOBAL_HEADER

    return ost^


def get_video_frame(
    mut ost: OutputStream,
    mut video: Video[DType.uint8],
    max_duration_seconds: Float32,
) raises -> UnsafePointer[AVFrame, MutExternalOrigin]:
    var comparison = avutil.av_compare_ts(
        ost.next_pts,
        ost.enc[].time_base,
        c_long_long(Int(max_duration_seconds)),
        AVRational(num=1, den=1),
    )

    if comparison > 0:
        _logger.info("No more frames to encode")
        return UnsafePointer[AVFrame, MutExternalOrigin]()

    if avutil.av_frame_make_writable(ost.frame) < 0:
        raise Error("Failed to make frame writable")

    var frame_idx = c_int(ost.next_pts)
    print("len video data frames: ", len(video))

    var frame_ptr = video.unsafe_ptr(Int(frame_idx))

    if video.color_space != ColorSpace.YUV_420P:
        if video.color_space == ColorSpace.RGBA_32:
            ost.conversion_frame[].format = AVPixelFormat.AV_PIX_FMT_RGBA._value
        else:
            raise Error("Unsupported color space: {}".format(video.color_space))
        ret = avutil.av_frame_make_writable(ost.conversion_frame)
        _check(ret, "Failed to make tmp frame writable: {}")
        ost.conversion_frame[].data[0] = frame_ptr.copy()
        ost.conversion_frame[].linesize[0] = c_int(video.linesize)
        print("Converting frame to alternate format.")

        convert_format(
            src_frame=ost.conversion_frame,  # TOD: should be from the video instead
            dst_frame=ost.frame,
            sws_ctx=ost.sws_ctx,
            enc=ost.enc,
            src_format=ost.conversion_frame[].format,
            dst_format=AVPixelFormat.AV_PIX_FMT_YUV420P._value,
        )
    else:
        ost.frame[].data[0] = frame_ptr.copy()

    # NOTE They use ++ which I think increments the next ptr itself actually, but
    # assignes the previous value to pts.
    ost.frame[].pts = ost.next_pts
    ost.next_pts += 1
    print("Next PTS: ", ost.next_pts)

    return ost.frame


def write_frame(
    mut fmt_ctx: UnsafePointer[AVFormatContext, MutExternalOrigin],
    mut ost: OutputStream,
    mut video: Video[DType.uint8],
    max_duration_seconds: Float32,
) raises -> c_int:
    var frame: UnsafePointer[AVFrame, ImmutExternalOrigin]
    if Int(ost.next_pts) >= len(video):
        # No more input frames: send NULL to flush encoder (drains buffered frames).
        frame = UnsafePointer[AVFrame, ImmutExternalOrigin]()
    else:
        frame = get_video_frame(ost, video, max_duration_seconds)

    var ret = c_int(0)

    _check(
        avcodec.avcodec_send_frame(ost.enc, frame), "Failed to send frame: {}"
    )

    while ret >= 0:
        ret = avcodec.avcodec_receive_packet(ost.enc, ost.pkt)
        if ret == AVERROR(ErrNo.EAGAIN.value) or ret == Int32(AVERROR_EOF):
            break
        _check(ret, "Failed to receive packet: {}")

        avcodec.av_packet_rescale_ts(
            ost.pkt, ost.enc[].time_base, ost.st[].time_base
        )
        ost.pkt[].stream_index = ost.st[].index
        _check(
            avformat.av_interleaved_write_frame(fmt_ctx, ost.pkt),
            "Failed to write packet: {}",
        )

        avcodec.av_packet_unref(ost.pkt)
        if ret < 0:
            break

    return c_int(ret == Int32(AVERROR_EOF))


def video_write(
    mut videos: List[Video[DType.uint8]],
    path: Path,
    fps: UInt = STREAM_FRAME_RATE,
    max_duration_seconds: Float32 = STREAM_DURATION,
) raises:
    """Write N video streams to `path`.

    Args:
        videos: The list of videos to write.
        path: The path to save the video to.
        fps: The frames per second of the video.
        max_duration_seconds: The maximum duration of the video in seconds.
    """
    _logger.info("Saving video to path: ", path)
    # alloc_output_context expects pointer-to-pointer: it allocates a new context
    # and stores it in *ctx. Passing a raw pointer causes use-after-free.
    # var packet = avcodec.av_packet_alloc()
    # var frame = avutil.av_frame_alloc()
    # alloc_output_context expects pointer-to-pointer: it allocates a new context
    # and stores it in *ctx. Passing a raw pointer causes use-after-free.
    var oc = alloc[UnsafePointer[AVFormatContext, MutExternalOrigin]](1)
    var path_s = String(path)
    var ret = avformat.avformat_alloc_output_context(
        ctx=oc,
        filename=path_s,
    )
    if ret < 0:
        raise Error("Failed to allocate output context: {}".format(ret))
    if not oc[]:
        raise Error("Failed to allocate output context")
    var opt = alloc[UnsafePointer[AVDictionary, MutExternalOrigin]](1)
    opt[] = UnsafePointer[AVDictionary, MutExternalOrigin]()

    var fmt = UnsafePointer(to=oc[][].oformat)
    if not fmt:
        raise Error("Failed to find output format")
    if fmt[][].video_codec == AVCodecID.AV_CODEC_ID_NONE._value:
        raise Error("Failed to find video codec")
    # var video_codec = UnsafePointer(to=oc[][].video_codec)

    if oc[][].oformat[].video_codec == AVCodecID.AV_CODEC_ID_NONE._value:
        raise Error("Failed to find video codec")

    var output_streams = List[OutputStream](capacity=Int(len(videos)))
    for ref video in videos:
        output_streams.append(add_stream(oc[], video, fps))
        open_video(oc[], output_streams[-1], opt[])

    avformat.av_dump_format(oc[], 0, path_s, 1)
    if not (oc[][].oformat[].flags & AVFMT_NOFILE):
        _check(
            avformat.avio_open(
                UnsafePointer(to=oc[][].pb),
                path_s,
                AVIO_FLAG_WRITE,
            ),
            "Failed to open output file: {}",
        )

    _check(
        avformat.avformat_write_header(oc[], opt), "Failed to write header: {}"
    )

    var i = 0
    for ref stream in output_streams:
        ref video = videos[i]
        var do_encode_video = True
        while do_encode_video:
            do_encode_video = (
                write_frame(oc[], stream, video, max_duration_seconds) == 0
            )
        i += 1

    _check(avformat.av_write_trailer(oc[]), "Failed to write trailer: {}")

    if not (oc[][].oformat[].flags & AVFMT_NOFILE) and oc[][].pb:
        var pb_ptr = alloc[UnsafePointer[AVIOContext, MutExternalOrigin]](1)
        pb_ptr[] = oc[][].pb
        _ = avformat.avio_closep(pb_ptr)
        oc[][].pb = pb_ptr[]
        pb_ptr.free()

    avformat.avformat_free_context(oc[])
    oc.free()
    opt.free()
