def rgb(r: UInt8, g: UInt8, b: UInt8) -> SIMD[DType.uint8, 4]:
    "Returns RGBA with alpha = 255."
    return SIMD[DType.uint8, 4](r, g, b, 255)


def rgba(r: UInt8, g: UInt8, b: UInt8, a: Float32) -> SIMD[DType.uint8, 4]:
    return SIMD[DType.uint8, 4](r, g, b, UInt8(a * 255.0))


comptime WHITE = rgb(255, 255, 255)
comptime BLACK = rgb(0, 0, 0)
comptime TRANSPARENT = rgba(0, 0, 0, 0)
comptime BLUE_E = rgb(39, 114, 151)
comptime PINK = rgb(255, 191, 202)
