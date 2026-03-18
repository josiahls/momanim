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


def open_video(
    oc: UnsafePointer[AVFormatContext, MutExternalOrigin],
    video_codec: UnsafePointer[AVCodec, ImmutExternalOrigin],
    mut ost: OutputStream,
    opt_arg: UnsafePointer[AVDictionary, ImmutExternalOrigin],
) raises:
    var ret: c_int = 0
    var c = ost.enc
    # NOTE: We need to add an override to avcodec_open2 that makes
    # an internal null pointer. Debug mode otherwise fails on this.
    var opt = UnsafePointer[AVDictionary, MutExternalOrigin]()
    var opt_ptr = alloc[UnsafePointer[AVDictionary, MutExternalOrigin]](1)
    opt_ptr[] = opt
    print("im opening a video")

    _ = avcodec.avcodec_open2(c, video_codec, opt_ptr)
    # av_dict_free(&opt);

    ost.frame = alloc_frame(c[].pix_fmt, c[].width, c[].height, c[].color_range)
    if not ost.frame:
        std.os.abort("Failed to allocate video frame")

    ost.tmp_frame = alloc_frame(
        c[].pix_fmt,
        c[].width,
        c[].height,
        c[].color_range,
    )

    ret = avcodec.avcodec_parameters_from_context(ost.st[].codecpar, c)
    if ret < 0:
        std.os.abort("Failed to copy the stream parameters")

    _ = c


def log_packet(
    fmt_ctx: UnsafePointer[AVFormatContext, MutExternalOrigin],
    pkt: UnsafePointer[AVPacket, MutExternalOrigin],
) raises:
    print(
        "pts:{} dts:{} duration:{} stream_index:{}".format(
            pkt[].pts,
            pkt[].dts,
            pkt[].duration,
            pkt[].stream_index,
        )
    )


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

    # fn __del__(deinit self):
    #     for i in range(len(self.data)):
    #         self.data[i].free()


def decode_packet(
    oc: UnsafePointer[AVFormatContext, MutExternalOrigin],
    video_codec_ctx: UnsafePointer[AVCodecContext, MutExternalOrigin],
    packet: UnsafePointer[AVPacket, MutExternalOrigin],
    frame: UnsafePointer[AVFrame, MutExternalOrigin],
    mut video_data: VideoData,
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

        convert_format(
            frame=frame,
            tmp_frame=tmp_frame,
            sws_ctx=oc[].sws_ctx,
            enc=oc[].enc,
            src_format=frame[].format,
            dst_format=video_data.format,
        )

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
        var video_stream = oc[].streams[i]
        var video_codec_id = video_stream[].codecpar[].codec_id
        var video_codec = avcodec.avcodec_find_decoder(video_codec_id)
        var video_codec_ctx = avcodec.avcodec_alloc_context3(video_codec)
        var video_data = VideoData()
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
                var pkt_ret = decode_packet(
                    oc, video_codec_ctx, packet, frame, video_datas[-1]
                )

            avcodec.av_packet_unref(packet)
            if ret < 0:
                break

        avcodec.avcodec_free_context(video_codec_ctx)
        # avcodec.avcodec_close(video_codec_ctx)

    avcodec.av_packet_free(packet)
    avutil.av_frame_free(frame)
    return video_datas^


struct OutputStream(Copyable, Movable):
    var st: UnsafePointer[AVStream, origin=MutExternalOrigin]
    var enc: UnsafePointer[AVCodecContext, origin=MutExternalOrigin]
    var next_pts: c_long_long
    var samples_count: c_int
    var frame: UnsafePointer[AVFrame, origin=MutExternalOrigin]
    var tmp_frame: UnsafePointer[AVFrame, origin=MutExternalOrigin]
    var tmp_pkt: UnsafePointer[AVPacket, origin=MutExternalOrigin]
    var t: c_float
    var tincr: c_float
    var tincr2: c_float
    var sws_ctx: UnsafePointer[SwsContext, origin=MutExternalOrigin]
    var swr_ctx: UnsafePointer[SwrContext, origin=MutExternalOrigin]

    fn __init__(out self) raises:
        self.st = UnsafePointer[AVStream, MutExternalOrigin]()
        self.enc = UnsafePointer[AVCodecContext, MutExternalOrigin]()
        self.next_pts = c_long_long(0)
        self.samples_count = c_int(0)
        self.frame = UnsafePointer[AVFrame, MutExternalOrigin]()
        self.tmp_frame = UnsafePointer[AVFrame, MutExternalOrigin]()
        self.tmp_pkt = UnsafePointer[AVPacket, MutExternalOrigin]()
        self.t = c_float(0)
        self.tincr = c_float(0)
        self.tincr2 = c_float(0)
        self.sws_ctx = UnsafePointer[SwsContext, MutExternalOrigin]()
        self.swr_ctx = UnsafePointer[SwrContext, MutExternalOrigin]()

    fn __del__(deinit self):
        if self.frame:
            avutil.av_frame_free(self.frame)
        if self.tmp_frame:
            avutil.av_frame_free(self.tmp_frame)
        if self.tmp_pkt:
            avcodec.av_packet_free(self.tmp_pkt)
        if self.enc:
            avcodec.avcodec_free_context(self.enc)


def get_video_frame(
    mut ost: OutputStream,
    video_data: VideoData,
) raises -> UnsafePointer[AVFrame, MutExternalOrigin]:
    var c = ost.enc

    var comparison = avutil.av_compare_ts(
        ost.next_pts,
        c[].time_base,
        c_long_long(Int(STREAM_DURATION)),
        AVRational(num=1, den=1),
    )

    if comparison > 0:
        _logger.info("No more frames to encode")
        return UnsafePointer[AVFrame, MutExternalOrigin]()

    _ = comparison
    _ = c

    if avutil.av_frame_make_writable(ost.frame) < 0:
        raise Error("Failed to make frame writable")

    var frame_idx = c_int(ost.next_pts)
    print("len video data frames: ", len(video_data.data))
    var frame_ptr = video_data.data[frame_idx]

    for c in range(video_data.n_color_spaces):
        var ptr = ost.frame[].data[c]
        var linesize = video_data.linesizes[c]
        for idx in range(linesize * video_data.height):
            ptr[][Int(idx)] = frame_ptr[idx]

        frame_ptr += linesize * video_data.height

    # NOTE They use ++ which I think increments the next ptr itself actually, but
    # assignes the previous value to pts.
    ost.frame[].pts = ost.next_pts
    ost.next_pts += 1
    print("Next PTS: ", ost.next_pts)

    return ost.frame


def write_frame(
    mut fmt_ctx: UnsafePointer[AVFormatContext, MutExternalOrigin],
    mut ost: OutputStream,
    video_data: VideoData,
) raises -> c_int:
    if ost.next_pts >= len(video_data.data):
        return c_int(Int32(AVERROR_EOF))
    var frame = get_video_frame(ost, video_data)

    ref pkt = ost.tmp_pkt
    ref st = ost.st
    ref c = ost.enc

    var ret = avcodec.avcodec_send_frame(c, frame)
    if ret < 0:
        raise Error("Failed to send frame: {}".format(ret))

    while ret >= 0:
        ret = avcodec.avcodec_receive_packet(c, pkt)
        if ret == AVERROR(ErrNo.EAGAIN.value) or ret == Int32(AVERROR_EOF):
            break
        elif ret < 0:
            raise Error("Failed to receive packet: {}".format(ret))

        avcodec.av_packet_rescale_ts(pkt, c[].time_base, st[].time_base)
        pkt[].stream_index = st[].index
        ret = avformat.av_interleaved_write_frame(fmt_ctx, pkt)
        if ret < 0:
            raise Error("Failed to write packet: {}".format(ret))

        avcodec.av_packet_unref(pkt)
        if ret < 0:
            break

    return c_int(ret == Int32(AVERROR_EOF))


def add_stream(
    mut osts: List[OutputStream],
    oc: UnsafePointer[AVFormatContext, MutExternalOrigin],
    codec: UnsafePointer[
        UnsafePointer[AVCodec, ImmutExternalOrigin], MutExternalOrigin
    ],
    codec_id: AVCodecID.ENUM_DTYPE,
    video_data: VideoData,
) raises:
    var i: c_int = 0
    var ost = OutputStream()
    # var c = alloc[AVCodecContext](1)

    codec[] = avcodec.avcodec_find_encoder(codec_id)
    if not codec[]:
        std.os.abort("Failed to find encoder")

    ost.tmp_pkt = avcodec.av_packet_alloc()
    if not ost.tmp_pkt:
        std.os.abort("Failed to allocate AVPacket")

    ost.st = avformat.avformat_new_stream(
        oc,
        # Add a null pointer.
        UnsafePointer[AVCodec, ImmutExternalOrigin](),
    )
    if not ost.st:
        std.os.abort("Failed to allocate stream")

    ost.st[].id = c_int(oc[].nb_streams - 1)

    var c = avcodec.avcodec_alloc_context3(codec[])
    if not c:
        std.os.abort("Failed to allocate encoding context")

    ost.enc = c

    ref codec_type = codec[][].type
    if codec_type == AVMediaType.AVMEDIA_TYPE_AUDIO._value:
        if not codec[][].sample_fmts:
            c[].sample_fmt = AVSampleFormat.AV_SAMPLE_FMT_FLTP._value
        else:
            # FIXME: Note that sample_fmts is deprecated and we should be using
            # avcodec_get_supported_config
            c[].sample_fmt = codec[][].sample_fmts[]
        c[].bit_rate = 64000
        c[].sample_rate = 44100
        if codec[][].supported_samplerates:
            c[].sample_rate = codec[][].supported_samplerates[]
            for i in count():
                if not codec[][].supported_samplerates[i]:
                    break
                if codec[][].supported_samplerates[i] == 44100:
                    c[].sample_rate = 44100

        var layout = alloc[AVChannelLayout](1)
        layout[] = AV_CHANNEL_LAYOUT_STEREO
        var dst = UnsafePointer(to=c[].ch_layout)
        ret = avutil.av_channel_layout_copy(dst, layout)
        if ret < 0:
            std.os.abort("Failed to copy channel layout")

        ost.st[].time_base = AVRational(num=1, den=c[].sample_rate)

    elif codec_type == AVMediaType.AVMEDIA_TYPE_VIDEO._value:
        c[].codec_id = codec_id
        c[].bit_rate = 400000
        # Resolution must be multople of two
        c[].width = video_data.width
        c[].height = video_data.height

        # Timebase: This is the fundamental unit of time (in seconds) in terms
        # of which frame timestamps are represented. For fixed-gps content
        # timebase should be 1/framerate and timestamp increments should be identical
        # to 1.
        ost.st[].time_base = AVRational(num=1, den=STREAM_FRAME_RATE)
        c[].time_base = ost.st[].time_base

        c[].gop_size = 12  # Emit one intra frame every twelve frames at most
        c[].pix_fmt = video_data.format
        if codec_id == AVCodecID.AV_CODEC_ID_MPEG2VIDEO._value:
            # Just for testing, we also add B-frames
            c[].max_b_frames = 2

        if codec_id == AVCodecID.AV_CODEC_ID_MPEG1VIDEO._value:
            # Needed to avoid using macroblocks in which some coeffs overflow.
            # This does not happen with normal video, it just happens here as
            # the motion of the chroma plane does not match the luma plane.
            c[].mb_decision = 2

        pass

    if oc[].oformat[].flags & AVFMT_GLOBALHEADER:
        c[].flags |= AV_CODEC_FLAG_GLOBAL_HEADER

    # ost.enc = ret
    osts.append(ost^)


def video_save(video_datas: List[VideoData], path: Path) raises:
    _logger.info("Saving video to path: ", path)
    var packet = avcodec.av_packet_alloc()
    var frame = avutil.av_frame_alloc()
    # alloc_output_context expects pointer-to-pointer: it allocates a new context
    # and stores it in *ctx. Passing a raw pointer causes use-after-free.
    var oc = alloc[UnsafePointer[AVFormatContext, MutExternalOrigin]](1)
    var path_s = String(path)
    var ret = avformat.alloc_output_context(
        ctx=oc,
        filename=path_s,
    )
    if ret < 0:
        raise Error("Failed to allocate output context: {}".format(ret))
    if not oc[]:
        raise Error("Failed to allocate output context")
    var opt = alloc[UnsafePointer[AVDictionary, MutExternalOrigin]](1)
    opt[] = UnsafePointer[
        AVDictionary, MutExternalOrigin
    ]()  # NULL, let FFmpeg manage

    var fmt = UnsafePointer(to=oc[][].oformat)
    if not fmt:
        raise Error("Failed to find output format")
    if fmt[][].video_codec == AVCodecID.AV_CODEC_ID_NONE._value:
        raise Error("Failed to find video codec")
    var video_codec = UnsafePointer(to=oc[][].video_codec)

    var output_streams = List[OutputStream](capacity=Int(len(video_datas)))
    for ref video_data in video_datas:
        add_stream(
            output_streams, oc[], video_codec, fmt[][].video_codec, video_data
        )
        open_video(oc[], video_codec[], output_streams[-1], opt[])

    avformat.av_dump_format(
        oc[],
        0,
        path_s,
        1,
    )
    if not (fmt[][].flags & AVFMT_NOFILE):
        ret = avformat.avio_open(
            UnsafePointer(to=oc[][].pb),
            path_s,
            AVIO_FLAG_WRITE,
        )
        if ret < 0:
            raise Error("Failed to open output file: {}".format(ret))

    ret = avformat.avformat_write_header(
        oc[],
        opt,
    )
    if ret < 0:
        raise Error("Failed to write header: {}".format(ret))

    var i = 0
    for ref stream in output_streams:
        ref video_data = video_datas[i]
        var do_encode_video = True
        while do_encode_video:
            var ret = write_frame(oc[], stream, video_data)
            do_encode_video = Bool(ret == 0)
        i += 1

    ret = avformat.av_write_trailer(oc[])
    if ret < 0:
        raise Error("Failed to write trailer: {}".format(ret))

    if oc[]:
        if not (fmt[][].flags & AVFMT_NOFILE) and oc[][].pb:
            var pb_ptr = alloc[UnsafePointer[AVIOContext, MutExternalOrigin]](1)
            pb_ptr[] = oc[][].pb
            _ = avformat.avio_closep(pb_ptr)
            oc[][].pb = pb_ptr[]
            pb_ptr.free()
