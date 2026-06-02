from momanim.stdlib_extensions import Enumable
from std.sys.info import size_of


struct BufferType(Enumable):
    comptime dtype = Int

    var _value: Self.dtype

    comptime PACKED_BYTE = Self(0)
    """A surface represented as a single contiguous byte buffer.

    Formats such as RGBA are stored in this type.
    """
    # TODO: For now there is not implmentation of the PlANAR_BYTES since we
    # don't use it.
    # comptime PLANAR_BYTE = Self(1)
    # """Traditional image represented as a multiple contiguous byte buffers.

    # Formats such as YUV are stored in this type.
    # """
    # comptime MASK = Self(2)
    # """A two dimensional image that stores values for use as a mask.

    # Formats such as A8 masks are stored in this type.
    # """
    comptime SOLID = Self(3)
    """A image that consists of a single value or color. 

    This is the most compact buffer type since it either onyl contains 1 value
    or a single color.
    """

    @implicit
    def __init__(out self, value: Self.dtype):
        self._value = value

    def __init__(out self, enum: Self):
        self._value = enum._value


comptime A8 = Scalar[DType.uint8]
comptime RGBA_F128 = SIMD[DType.float32, 4]
comptime RGBA_U32 = SIMD[DType.uint8, 4]

# Default RGBA is a floating point 32 bit per channel
comptime RGBA = RGBA_F128
"Default RGBA is a floating point 32 bit per channel pixel ranging 0 -1."


trait Surfaceable(Movable, Writable):
    """An Surface like object."""

    pass
    # comptime buffer_type: ImageBufferType

    # This is a trait instead of a variant since the "sizes" of the various
    # dtypes are very wide ranging.


def _fill_buffer[
    dtype: DType, width: Int, //, batch_size: Int
](
    mut buffer: UnsafePointer[SIMD[dtype, width], MutExternalOrigin],
    fill: SIMD[dtype, width],
    size: Int,
    msg: StaticString,
):
    var unroll_end = std.math.align_down(size, batch_size)
    var ptr = buffer

    for _ in range(0, unroll_end, batch_size):
        comptime for _ in range(batch_size):
            ptr.init_pointee_copy(fill)
            ptr += 1

    # Fill the remainder
    for _ in range(unroll_end, size):
        ptr.init_pointee_copy(fill)
        ptr += 1
    debug_assert(ptr == buffer + size, msg)


# TODO: Parameterize later.
struct ColorSurface(Surfaceable):
    comptime buffer_type = BufferType.PACKED_BYTE

    # TODO: Parameterize later. Also I think newer mojo versions fix the infrerence.
    comptime format = RGBA

    var buffer: UnsafePointer[Self.format, MutExternalOrigin]
    var width: Int
    var height: Int
    var channels: Int
    var len_line_bytes: Int
    var len_bytes: Int
    var size: Int

    # TODO: switch to batch_size: SIMDSize
    def __init__[
        batch_size: Int = 64
    ](
        out self,
        fill: Self.format,
        width: Int,
        height: Int,
        channels: Int = Self.format.size,
        line_alignment: Int = 16,
    ):
        self.width = width
        self.height = height
        self.channels = channels
        # TODO: A little confusing here. The line size is the number of
        # elements in a row. In RGBA's case, this is 4 subelements.
        # Normally the line size is the literal number of bytes e.g.:
        # line_size = width * channels.
        # However UnsafePointer[0] gives you [R,G,B,A]
        # Maybe revisit. We may want to have UnsafePointer store Scalar[dtype]
        # so line size makes more sense, however on the other hand, its probably
        # better top operation in RGBA = SIMD[dtype, 4] world?

        # Additional confusion, even if the width doesn't itself line up, and
        # requires alighnment, if the underlying dtype is something like RGB,
        # 24 bits, its possible the required alignment will be different as
        # opposed to aligning RGBA.
        self.size = self.width * height
        self.len_line_bytes = self.width * size_of[self.format]()

        self.len_bytes = self.len_line_bytes * height
        self.buffer = alloc[Self.format](self.size)

        _fill_buffer[batch_size=batch_size](
            self.buffer,
            fill,
            self.size,
            "error during `ColorSurface` initialization",
        )


# TODO: Parameterize later.
struct MaskSurface(Surfaceable):
    comptime buffer_type = BufferType.PACKED_BYTE

    # TODO: Parameterize later. Also I think newer mojo versions fix the infrerence.
    comptime format = A8

    var buffer: UnsafePointer[Self.format, MutExternalOrigin]
    var width: Int
    var height: Int
    var line_size: Int
    var size: Int

    # TODO: switch to batch_size: SIMDSize
    def __init__[
        batch_size: Int = 64
    ](
        out self,
        fill: Self.format,
        width: Int,
        height: Int,
        line_alignment: Int = 16,
    ):
        self.width = width
        self.height = height
        self.line_size = std.math.align_up(self.width, line_alignment)
        self.size = self.line_size * height
        self.buffer = alloc[Self.format](self.size)
        _fill_buffer[batch_size=batch_size](
            self.buffer,
            fill,
            self.size,
            "error during `MaskSurface` initialization",
        )


# TODO: Parameterize later.
struct SolidSurface(Surfaceable):
    comptime buffer_type = BufferType.SOLID

    # TODO: Parameterize later. Also I think newer mojo versions fix the infrerence.
    comptime format = RGBA

    var buffer: InlineArray[Scalar[Self.format.dtype], Self.format.size]

    def __init__(out self, rgba: Self.format):
        # TODO: See if updating mojo allows us to remove this.
        # there really no reason to need to rebind.
        self.buffer = rebind[type_of(self.buffer)](rgba.as_bytes())
