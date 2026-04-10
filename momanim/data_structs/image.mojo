from numojo.core import DataContainer
from std.ffi import c_uchar
from momanim.constants import ColorSpace
import numojo as nm


struct Image[dtype: DType = DType.uint8](Movable, Writable):
    var _data: DataContainer[Self.dtype]
    var w: UInt
    var h: UInt
    var ch: UInt
    "Number of channels (or planes in ffmpeg parlance)."
    var color_space: ColorSpace
    "Defines how the underlying pointer data is to be interpreted."
    var io_backend_opaque_params: Dict[String, OpaquePointer[MutExternalOrigin]]
    """Private params used by the io backend to read or write this Image."""
    var line_size: UInt
    """Bytes per row (row stride). Must match the underlying buffer layout."""

    def __init__(out self, var elems: List[Scalar[Self.dtype]]) raises:
        self.w = UInt(len(elems))
        if len(elems) % 3 != 0:
            raise Error(
                """Default init of `Image` from a list of elements
                must be a multiple of 3 since the default color space is 
                RGB_24 e.g. [R,G,B,R,G,B,...]"""
            )
        self.h = 1
        self.ch = 1
        self.line_size = self.w
        self._data = DataContainer(
            ptr=elems.unsafe_ptr().unsafe_origin_cast[MutExternalOrigin](),
            size=len(elems),
            copy=False,
        )
        self.color_space = ColorSpace.RGB_24
        self.io_backend_opaque_params = {}

    def __init__(
        out self,
        w: UInt,
        h: UInt,
        ch: UInt,
        line_size: UInt,
        color_space: ColorSpace,
        container: DataContainer[Self.dtype],
    ) raises:
        self.w = w
        self.h = h
        self.ch = ch
        self.line_size = line_size
        self.color_space = color_space
        self.io_backend_opaque_params = {}
        self._data = container.copy()

    def __init__(
        out self,
        var ptr: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin],
        size: Int,
        line_size: UInt,
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
        self.line_size = line_size
        self._data = DataContainer(
            ptr=ptr.unsafe_origin_cast[MutExternalOrigin](),
            size=size,
            copy=False,
        )
        self.color_space = ColorSpace.RGB_24
        self.io_backend_opaque_params = {}

    def numojo(mut self) raises -> nm.NDArray[Self.dtype]:
        var array = nm.NDArray[Self.dtype](
            shape=nm.NDArrayShape(Int(self.h), Int(self.w), Int(self.ch)),
            is_view=True,
            data=self._data.copy(),
            # TODO: I think we need to factor in the linesize somehow.
            strides=nm.NDArrayStrides(Int(self.line_size), Int(self.ch), 1),
            offset=0,
        )
        return array^
