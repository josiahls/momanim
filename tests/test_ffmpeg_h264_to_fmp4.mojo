from std.testing import TestSuite, assert_equal
from std.pathlib import Path
from std.memory import memset
from std.itertools import count
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
from mav.ffmpeg.swscale import SwsFilter
from mav.ffmpeg import swscale
from mav.ffmpeg import swrsample
from mav.ffmpeg.swrsample import SwrContext
from std.utils import StaticTuple


comptime STREAM_FRAME_RATE = 25
comptime STREAM_DURATION = 10.0
comptime STREAM_PIX_FMT = AVPixelFormat.AV_PIX_FMT_YUV420P._value

comptime SCALE_FLAGS = SwsFlags.SWS_BICUBIC


@fieldwise_init
struct OutputStream(Movable):
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


def alloc_frame(
    pix_fmt: AVPixelFormat.ENUM_DTYPE,
    width: c_int,
    height: c_int,
) raises -> UnsafePointer[AVFrame, MutExternalOrigin]:
    var frame = avutil.av_frame_alloc()

    frame[].format = pix_fmt
    frame[].width = width
    frame[].height = height

    ret = avutil.av_frame_get_buffer(
        frame.unsafe_origin_cast[MutExternalOrigin](), 0
    )
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

    ost.frame = alloc_frame(
        c[].pix_fmt, c[].width, c[].height
    ).unsafe_origin_cast[MutExternalOrigin]()
    if not ost.frame:
        std.os.abort("Failed to allocate video frame")

    ost.tmp_frame = UnsafePointer[AVFrame, MutExternalOrigin]()
    if c[].pix_fmt != AVPixelFormat.AV_PIX_FMT_YUV420P._value:
        ost.tmp_frame = alloc_frame(
            AVPixelFormat.AV_PIX_FMT_YUV420P._value,
            c[].width,
            c[].height,
        ).unsafe_origin_cast[MutExternalOrigin]()
        if not ost.tmp_frame:
            std.os.abort("Failed to allocate temporary video frame")

    ret = avcodec.avcodec_parameters_from_context(ost.st[].codecpar, c)
    if ret < 0:
        std.os.abort("Failed to copy the stream parameters")

    _ = c


def add_stream(
    mut ost: OutputStream,
    oc: UnsafePointer[AVFormatContext, MutExternalOrigin],
    codec: UnsafePointer[
        UnsafePointer[AVCodec, ImmutExternalOrigin], MutExternalOrigin
    ],
    codec_id: AVCodecID.ENUM_DTYPE,
) raises:
    var i: c_int = 0
    var c = alloc[AVCodecContext](1)

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

    c = avcodec.avcodec_alloc_context3(codec[])
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
        c[].width = 352
        c[].height = 288

        # Timebase: This is the fundamental unit of time (in seconds) in terms
        # of which frame timestamps are represented. For fixed-gps content
        # timebase should be 1/framerate and timestamp increments should be identical
        # to 1.
        ost.st[].time_base = AVRational(num=1, den=STREAM_FRAME_RATE)
        c[].time_base = ost.st[].time_base

        c[].gop_size = 12  # Emit one intra frame every twelve frames at most
        c[].pix_fmt = STREAM_PIX_FMT
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


def fill_yuv_image(
    frame: UnsafePointer[AVFrame, MutExternalOrigin],
    frame_index: c_int,
    width: c_int,
    height: c_int,
) raises:
    var x: c_int = 0
    var y: c_int = 0
    var i: c_int = frame_index
    for y in range(height):
        for x in range(width):
            frame[].data[0][y * frame[].linesize[0] + x] = c_uchar(
                x + y + i * 3
            )
    for y in range(height / 2):
        for x in range(width / 2):
            frame[].data[1][y * frame[].linesize[1] + x] = c_uchar(
                128 + y + i * 2
            )
            frame[].data[2][y * frame[].linesize[2] + x] = c_uchar(
                64 + x + i * 5
            )


def get_video_frame(
    mut ost: OutputStream,
) raises -> UnsafePointer[AVFrame, MutExternalOrigin]:
    var c = ost.enc

    var comparison = avutil.av_compare_ts(
        ost.next_pts,
        c[].time_base,
        c_long_long(Int(STREAM_DURATION)),
        AVRational(num=1, den=1),
    )

    if comparison > 0:
        return UnsafePointer[AVFrame, MutExternalOrigin]()

    _ = comparison
    _ = c

    if avutil.av_frame_make_writable(ost.frame) < 0:
        std.os.abort("Failed to make frame writable")

    if c[].pix_fmt != AVPixelFormat.AV_PIX_FMT_YUV420P._value:
        if not ost.sws_ctx:
            ost.sws_ctx = swscale.sws_getContext(
                c[].width,
                c[].height,
                AVPixelFormat.AV_PIX_FMT_YUV420P._value,
                c[].width,
                c[].height,
                c[].pix_fmt,
                SCALE_FLAGS.value,
                UnsafePointer[SwsFilter, MutExternalOrigin](),
                UnsafePointer[SwsFilter, MutExternalOrigin](),
                UnsafePointer[c_double, ImmutExternalOrigin](),
            )
            if not ost.sws_ctx:
                std.os.abort("Failed to initialize conversion context")

        # API wise, this seems problematic no? These are all long longs
        # and we are converting to ints.
        fill_yuv_image(
            ost.tmp_frame,
            c_int(ost.next_pts),
            c_int(c[].width),
            c_int(c[].height),
        )

        # TODO: There has to be a better way to do this.
        # We should at least not be doing the allocations in a hot loop.
        var src_slice = alloc[UnsafePointer[c_uchar, ImmutExternalOrigin]](
            len(ost.tmp_frame[].data)
        )
        for i in range(len(ost.tmp_frame[].data)):
            src_slice[i] = ost.tmp_frame[].data[i].as_immutable()

        var dst = alloc[UnsafePointer[c_uchar, MutExternalOrigin]](
            len(ost.frame[].data)
        )
        for i in range(len(ost.frame[].data)):
            dst[i] = ost.frame[].data[i]

        # NOTE: https://github.com/modular/modular/pull/5715
        # adds unsafe_ptr to StaticTuple, which is needed for this.
        var res = swscale.sws_scale(
            ost.sws_ctx,
            src_slice,
            ost.tmp_frame[].linesize.unsafe_ptr(),
            0,
            c[].height,
            dst,
            ost.frame[].linesize.unsafe_ptr(),
        )
        if res < 0:
            std.os.abort("Failed to scale image")
    else:
        fill_yuv_image(
            ost.frame, c_int(ost.next_pts), c_int(c[].width), c_int(c[].height)
        )

    # NOTE They use ++ which I think increments the next ptr itself actually, but
    # assignes the previous value to pts.
    ost.frame[].pts = ost.next_pts
    ost.next_pts += 1

    return ost.frame


def write_frame(
    fmt_ctx: UnsafePointer[AVFormatContext, MutExternalOrigin],
    c: UnsafePointer[AVCodecContext, MutExternalOrigin],
    st: UnsafePointer[AVStream, MutExternalOrigin],
    frame: UnsafePointer[AVFrame, MutExternalOrigin],
    pkt: UnsafePointer[AVPacket, MutExternalOrigin],
) raises -> c_int:
    # TODO: Check pkt. It looks completely invalid.
    var ret = c_int(0)
    ret = avcodec.avcodec_send_frame(c, frame)
    if ret < 0:
        std.os.abort("Failed to send frame to encoder")
    _ = frame
    while ret >= 0:
        ret = avcodec.avcodec_receive_packet(c, pkt)

        if ret == AVERROR(ErrNo.EAGAIN.value) or ret == Int32(AVERROR_EOF):
            break
        elif ret < 0:
            print(avutil.av_err2str(ret))
            std.os.abort(
                "Failed to receive packet from encoder with ret val: {}".format(
                    ret
                )
            )

        avcodec.av_packet_rescale_ts(pkt, c[].time_base, st[].time_base)
        pkt[].stream_index = st[].index

        log_packet(fmt_ctx, pkt)
        ret = avformat.av_interleaved_write_frame(fmt_ctx, pkt)
        if ret < 0:
            std.os.abort("Failed to write output packet")

    # _ = avcodec
    # _ = avformat
    return c_int(ret == Int32(AVERROR_EOF))


def write_video_frame(
    oc: UnsafePointer[AVFormatContext, MutExternalOrigin],
    mut ost: OutputStream,
) raises -> c_int:
    var ret = write_frame(
        fmt_ctx=oc,
        c=ost.enc,
        st=ost.st,
        frame=get_video_frame(ost),
        pkt=ost.tmp_pkt,
    )
    return ret


def test_av_mux_example() raises:
    """From: https://www.ffmpeg.org/doxygen/8.0/mux_8c-example.html."""
    var video_st = OutputStream()
    # NOTE: Not interested in audio at the moment.
    # var audio_st = OutputStream()
    var fmt = alloc[UnsafePointer[AVOutputFormat, ImmutExternalOrigin]](1)
    var oc = alloc[UnsafePointer[AVFormatContext, MutExternalOrigin]](1)
    # var oc = UnsafePointer[AVFormatContext, MutAnyOrigin]()
    # NOTE: Not interested in audio at the moment.
    # var audio_codec = AVCodec()
    var video_codec = alloc[UnsafePointer[AVCodec, ImmutExternalOrigin]](1)
    var ret = c_int(0)
    var have_video = c_int(0)
    # NOTE: Not interested in audio at the moment.
    # var have_audio = c_int(0)
    var encode_video = c_int(0)
    # var encode_audio = c_int(0)
    var opt = alloc[UnsafePointer[AVDictionary, MutExternalOrigin]](1)
    opt[] = UnsafePointer[
        AVDictionary, MutExternalOrigin
    ]()  # NULL, let FFmpeg manage
    var opt2 = alloc[UnsafePointer[AVDictionary, MutExternalOrigin]](1)
    opt2[] = UnsafePointer[
        AVDictionary, MutExternalOrigin
    ]()  # NULL, let FFmpeg manage
    var i = c_int(0)

    var test_data_root = std.os.getenv("PIXI_PROJECT_ROOT")
    # Currently auto gens frames
    # var input_filename: String = (
    #     "{}/test_data/testsrc_320x180_30fps_2s.h264".format(test_data_root)
    # )
    var output_filename: String = (
        "{}/test_data/dash_mojo/testsrc_320x180_30fps_2s.mpd".format(
            test_data_root
        )
    )
    var parent_path_parts = Path(output_filename).parts()[:-1]
    var parent_path = Path(String(std.os.sep).join(parent_path_parts))
    std.os.makedirs(parent_path, exist_ok=True)

    # FIXME: Tryout without any flags, just h264 to mp4.
    # ret = avformat.alloc_output_context(oc, output_filename)

    ret = avformat.alloc_output_context(
        ctx=oc,
        filename=output_filename,
    )
    if not oc or ret < 0:
        std.os.abort("Failed to allocate output context")
        # Note: The example: mux.c will switch to 'mpeg' on failure. In our case
        # however, we want to be strict about the expected behavior.

    fmt = UnsafePointer(to=oc[][].oformat)
    video_codec = UnsafePointer(to=oc[][].video_codec)

    if fmt[][].video_codec != AVCodecID.AV_CODEC_ID_NONE._value:
        print("video codec is not none: ", fmt[][].video_codec)
        add_stream(video_st, oc[], video_codec, fmt[][].video_codec)
        have_video = 1
        encode_video = 1
    else:
        print("video codec is none")
    # if fmt[].audio_codec != AV_CODEC_ID_NONE:
    #     print("audio codec is not none")
    # else:
    #     print("audio codec is none")

    if have_video:
        open_video(oc[], video_codec[], video_st, opt[])

    # Not interested in audio at the moment.
    # if have_audio:
    #     open_audio(avformat, avcodec, oc[], audio_codec[], audio_st, opt[])

    avformat.av_dump_format(
        oc[],
        0,
        output_filename,
        1,
    )

    if not (fmt[][].flags & AVFMT_NOFILE):
        ret = avformat.avio_open(
            UnsafePointer(to=oc[][].pb),
            output_filename,
            AVIO_FLAG_WRITE,
        )
        if ret < 0:
            std.os.abort("Failed to open output file: {}".format(ret))
            # TODO: Not sure if mojo can access stderror or not?
            # Would be ideal since that would surface the error message to the user.
            # fprintf(stderr, "Could not open '%s': %s\n", filename,
            #         av_err2str(ret));

    print("writing header")
    ret = avformat.avformat_write_header(
        oc[],
        opt2,
    )
    print("dune writing")
    if ret < 0:
        std.os.abort("Failed to write header: {}".format(ret))
        # TODO: Not sure if mojo can access stderror or not?
        # Would be ideal since that would surface the error message to the user.
        # fprintf(stderr, "Error occurred when opening output file: %s\n",
        #         av_err2str(ret));

    while encode_video:
        # TODO: This if statement is only needed when using audio.
        # if encode_video and avutil.av_compare_ts(
        #     video_st.next_pts,
        #     video_st.enc->time_base,
        #     audio_st.next_pts,
        #     audio_st.enc->time_base
        # ) <= 0:
        if encode_video:
            var result = write_video_frame(oc[], video_st)
            # print("Result: {}".format(result))
            encode_video = c_int(result == 0)
        # else:
        #     encode_audio = !write_audio_frame(oc, &audio_st)

    ret = avformat.av_write_trailer(oc[])
    if ret < 0:
        std.os.abort("Failed to write trailer: {}".format(ret))

    if oc[]:
        if not (fmt[][].flags & AVFMT_NOFILE) and oc[][].pb:
            var pb_ptr = alloc[UnsafePointer[AVIOContext, MutExternalOrigin]](1)
            pb_ptr[] = oc[][].pb
            _ = avformat.avio_closep(pb_ptr)
            oc[][].pb = pb_ptr[]
            pb_ptr.free()
        avformat.avformat_free_context(oc[])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
