trait ColorType(Equatable, TrivialRegisterPassable, Writable):
    pass


@fieldwise_init
struct A8(ColorType, Movable):
    var value: Scalar[DType.uint8]


@fieldwise_init
struct RGBA_Float32(ColorType, Movable):
    comptime size = 4
    comptime dtype = DType.float32
    var value: SIMD[Self.dtype, Self.size]

    def __init__(out self, r: Float32, g: Float32, b: Float32, a: Float32):
        self.value = [r, g, b, a]
        comptime msg = "RGBA_F must be flaoting point values ranging [0, 1]"
        assert self.value.reduce_min() >= 0, msg
        assert self.value.reduce_max() <= 1, msg


struct RGBA_UInt8(ColorType):
    comptime size = 4
    comptime dtype = DType.uint8
    var value: SIMD[Self.dtype, Self.size]

    @implicit
    def __init__(out self, var value: SIMD[Self.dtype, Self.size]):
        self.value = value

    @staticmethod
    def cast_from(value: RGBA_Float32) -> Self:
        var val = (value.value * 255).clamp(0, 255).cast[Self.dtype]()
        return Self(val)


comptime RGBA = RGBA_UInt8
comptime RGBA_F = RGBA_Float32
