from numojo.core import DataContainer
from std.ffi import c_uchar
from momanim.constants import ColorSpace
import numojo as nm


struct VideoFrame[dtype: DType = DType.uint8](Copyable, Movable, Writable):
    var _data: DataContainer[Self.dtype]

    fn __init__(
        out self,
        var ptr: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin],
        size: Int,
        copy: Bool = False,
    ) raises:
        self._data = DataContainer(
            ptr=ptr.unsafe_origin_cast[MutExternalOrigin](),
            size=size,
            copy=copy,
        )


struct Video[dtype: DType = DType.uint8](Copyable, Movable, Sized, Writable):
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
    var linesize: Int
    """Bytes per row (row stride). Must match the underlying buffer layout."""

    fn __init__(out self) raises:
        self.w = 0
        self.h = 0
        self.ch = 0
        self._frames = List[VideoFrame[Self.dtype]]()
        self.color_space = ColorSpace.RGB_24
        self.io_backend_opaque_params = {}
        self.linesize = 0

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
        self.linesize = len(elems)
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
        self.linesize = size
        var frame = VideoFrame(ptr, size)
        self._frames.append(frame^)
        self.color_space = ColorSpace.RGB_24
        self.io_backend_opaque_params = {}

    fn steal_frame(
        mut self,
        var frame_ptr: UnsafePointer[
            UnsafePointer[Scalar[Self.dtype], MutExternalOrigin],
            MutExternalOrigin,
        ],
        linesize: Int,
        copy: Bool = False,
    ) raises:
        self.linesize = linesize
        var buf_size = linesize * Int(self.h)
        var frame = VideoFrame[Self.dtype](frame_ptr[0], buf_size, copy=copy)
        self._frames.append(frame^)

    fn frame(
        ref self, frame_idx: Int
    ) -> ref[self._frames[frame_idx]] VideoFrame[Self.dtype]:
        return self._frames[frame_idx]

    fn unsafe_ptr(
        mut self, frame_idx: Int
    ) -> UnsafePointer[Scalar[Self.dtype], MutExternalOrigin]:
        return self._frames[frame_idx]._data.ptr

    fn numojo(mut self, frame_idx: Int) raises -> nm.NDArray[Self.dtype]:
        var row_stride = self.linesize
        var array = nm.NDArray[Self.dtype](
            shape=nm.NDArrayShape(Int(self.h), Int(self.w), Int(self.ch)),
            is_view=True,
            data=self._frames[frame_idx]._data.copy(),
            strides=nm.NDArrayStrides(row_stride, Int(self.ch), 1),
            offset=0,
        )
        return array^

    fn __len__(self) -> Int:
        return len(self._frames)
