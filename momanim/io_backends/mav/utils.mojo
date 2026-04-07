from mav.ffmpeg.swscale.swscale import SwsContext, SwsDither
from std.ffi import c_uchar, c_int, c_double
from mav.ffmpeg import avutil
from mav.ffmpeg.avutil.pixfmt import AVPixelFormat
from mav.ffmpeg import swscale
from mav.ffmpeg.swscale import SwsFilter
from mav.ffmpeg.avutil.frame import AVFrame
from mav.ffmpeg.avcodec.avcodec import AVCodecContext
from mav.ffmpeg.swscale.swscale import SwsFlags


# BITEXACT + ACCURATE_RND: YUV→RGB rounding can otherwise differ by ±1 between
# SIMD implementations (e.g. AArch64 NEON vs x86), breaking pixel-exact tests.
comptime SCALE_FLAGS = SwsFlags(
    SwsFlags.SWS_BICUBIC.value
    | SwsFlags.SWS_ACCURATE_RND.value
    | SwsFlags.SWS_BITEXACT.value
)


def convert_format(
    mut src_frame: UnsafePointer[AVFrame, origin=MutExternalOrigin],
    mut dst_frame: UnsafePointer[AVFrame, origin=MutExternalOrigin],
    mut sws_ctx: UnsafePointer[
        UnsafePointer[SwsContext, origin=MutExternalOrigin],
        origin=MutExternalOrigin,
    ],
    mut enc: UnsafePointer[AVCodecContext, origin=MutExternalOrigin],
    src_format: AVPixelFormat.ENUM_DTYPE,
    dst_format: AVPixelFormat.ENUM_DTYPE,
) raises:
    # Use actual frame dimensions: decoded frame can differ from codec context
    # (e.g. crop, alignment, or mid-stream resolution change).
    var src_w = src_frame[].width
    var src_h = src_frame[].height
    var dst_w = dst_frame[].width
    var dst_h = dst_frame[].height

    if not sws_ctx[]:
        sws_ctx[] = swscale.sws_getContext(
            src_w,
            src_h,
            src_format,
            dst_w,
            dst_h,
            dst_format,
            SCALE_FLAGS.value,
            UnsafePointer[SwsFilter, MutExternalOrigin](),
            UnsafePointer[SwsFilter, MutExternalOrigin](),
            UnsafePointer[c_double, ImmutExternalOrigin](),
        )
        if not sws_ctx[]:
            raise Error("Failed to initialize conversion context")
        # RGB8 (e.g. GIF): libswscale may dither when packing to 3:3:2; match CLI `-sws_dither none`.
        if dst_format == AVPixelFormat.AV_PIX_FMT_RGB8._value:
            sws_ctx[][].dither = SwsDither.SWS_DITHER_NONE.value

    # TODO: Get the number of planes, should be able to do `len(src_frame[].data)`
    var src_slice = alloc[UnsafePointer[c_uchar, ImmutExternalOrigin]](8)
    for i in range(8):
        src_slice[i] = src_frame[].data[i].as_immutable()
    var dst_slice = alloc[UnsafePointer[c_uchar, MutExternalOrigin]](8)
    for i in range(8):
        dst_slice[i] = dst_frame[].data[i]

    # NOTE: https://github.com/modular/modular/pull/5715
    # adds unsafe_ptr to StaticTuple, which is needed for this.
    var res = swscale.sws_scale(
        sws_ctx[],
        src_slice,
        src_frame[].linesize.unsafe_ptr(),
        0,
        src_h,
        dst_slice,
        dst_frame[].linesize.unsafe_ptr(),
    )
    src_slice.free()
    dst_slice.free()
    if res < 0:
        raise Error("Failed to scale image: {}".format(avutil.av_err2str(res)))
