from mav.ffmpeg.swscale.swscale import SwsContext
from std.ffi import c_uchar, c_int, c_double
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat
from mav.ffmpeg import swscale
from mav.ffmpeg.swscale import SwsFilter
from mav.ffmpeg.avutil.frame import AVFrame
from mav.ffmpeg.avcodec.avcodec import AVCodecContext
from mav.ffmpeg.swscale.swscale import SwsFlags


comptime SCALE_FLAGS = SwsFlags.SWS_BICUBIC


def convert_format(
    mut frame: UnsafePointer[AVFrame, origin=MutExternalOrigin],
    mut tmp_frame: UnsafePointer[AVFrame, origin=MutExternalOrigin],
    mut sws_ctx: UnsafePointer[
        UnsafePointer[SwsContext, origin=MutExternalOrigin],
        origin=MutExternalOrigin,
    ],
    mut enc: UnsafePointer[AVCodecContext, origin=MutExternalOrigin],
    src_format: AVPixelFormat.ENUM_DTYPE,
    dst_format: AVPixelFormat.ENUM_DTYPE,
) raises:
    if not sws_ctx[]:
        print("initializing conversion context")
        sws_ctx[] = swscale.sws_getContext(
            enc[].width,
            enc[].height,
            # TODO: We want to instead of default to RGB24
            # AVPixelFormat.AV_PIX_FMT_YUV420P._value,
            src_format,
            enc[].width,
            enc[].height,
            enc[].pix_fmt,
            SCALE_FLAGS.value,
            UnsafePointer[SwsFilter, MutExternalOrigin](),
            UnsafePointer[SwsFilter, MutExternalOrigin](),
            UnsafePointer[c_double, ImmutExternalOrigin](),
        )
        print("conversion context initialized, sws_ctx: ")
        if not sws_ctx:
            raise Error("Failed to initialize conversion context")

    print("conversion context initialized")
    # TODO: There has to be a better way to do this.
    # We should at least not be doing the allocations in a hot loop.
    var src_slice = alloc[UnsafePointer[c_uchar, ImmutExternalOrigin]](
        len(tmp_frame[].data)
    )
    for i in range(len(tmp_frame[].data)):
        print("src_slice[i]: ", src_slice[i])
        print("tmp_frame[].data[i]: ", tmp_frame[].data[i])
        src_slice[i] = tmp_frame[].data[i].as_immutable()

    var dst = alloc[UnsafePointer[c_uchar, MutExternalOrigin]](
        len(frame[].data)
    )
    for i in range(len(frame[].data)):
        dst[i] = frame[].data[i]

    # NOTE: https://github.com/modular/modular/pull/5715
    # adds unsafe_ptr to StaticTuple, which is needed for this.
    var res = swscale.sws_scale(
        sws_ctx[],
        src_slice,
        tmp_frame[].linesize.unsafe_ptr(),
        0,
        enc[].height,
        dst,
        frame[].linesize.unsafe_ptr(),
    )
    if res < 0:
        raise Error("Failed to scale image")
