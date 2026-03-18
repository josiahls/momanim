from numojo.core import DataContainer
from std.ffi import c_uchar
from momanim.constants import ColorSpace


struct VideoFrame[dtype: DType = DType.uint8](Copyable, Movable, Writable):
    var _data: DataContainer[Self.dtype]

    fn __init__(
        out self,
        var ptr: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin],
        size: Int,
    ) raises:
        self._data = DataContainer(
            ptr=ptr.unsafe_origin_cast[MutExternalOrigin](),
            size=size,
            copy=False,
        )


struct Video[dtype: DType = DType.uint8](Movable, Writable):
    var _frames: List[VideoFrame[Self.dtype]]
    """Frames for videos. These are private since the user should use `frame()` which 
    composes the underlying frame data with its width / height.

    The `VideoFrame` is intended to be very very minimal.
    """
    var w: UInt
    var h: UInt
    var ch: UInt
    "Number of channels (or planes in ffmpeg parlance)."
    var color_space: ColorSpace
    "Defines how the underlying pointer data is to be interpreted."
    var io_backend_opaque_params: Dict[String, OpaquePointer[MutExternalOrigin]]
    """Private params used by the io backend to read or write this Video."""

    fn __init__(out self, var elems: List[Scalar[Self.dtype]]) raises:
        self.w = UInt(len(elems))
        if len(elems) % 3 != 0:
            raise Error(
                """Default init of `Image` from a list of elements
                must be a multiple of 3 since the default color space is 
                RGB_24 e.g. [R,G,B,R,G,B,...]"""
            )
        self.h = 1
        self.ch = 1
        self._frames = List[VideoFrame[Self.dtype]]()
        var frame = VideoFrame(
            elems.unsafe_ptr().unsafe_origin_cast[MutExternalOrigin](),
            len(elems),
        )
        self._frames.append(frame^)
        self.color_space = ColorSpace.RGB_24
        self.io_backend_opaque_params = {}

    fn __init__(
        out self,
        var ptr: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin],
        size: Int,
    ) raises:
        self.w = UInt(size)
        if size % 3 != 0:
            raise Error(
                """Default init of `Image` from a list of elements
                must be a multiple of 3 since the default color space is 
                RGB_24 e.g. [R,G,B,R,G,B,...]"""
            )
        self.h = 1
        self.ch = 1
        self._frames = List[VideoFrame[Self.dtype]]()
        var frame = VideoFrame(ptr, size)
        self._frames.append(frame^)
        self.color_space = ColorSpace.RGB_24
        self.io_backend_opaque_params = {}
