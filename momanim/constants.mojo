from momanim.stdlib_extensions import Enumable


struct ColorSpace(Enumable):
    comptime dtype = Int
    var value: Self.dtype

    comptime UNSPECIFIED = Self(0)

    comptime RGB_24 = Self(1)
    """Packed RGB 8:8:8, 24bpp, RGBRGB...
    
    Default for `momanim`. 
    """
    comptime YUV_420P = Self(2)
    """Planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples).
    
    Defualt in ffmpeg (at least their examples)
    - https://ffmpeg.org//doxygen/trunk/pixfmt_8h.html#a9a8e335cf3be472042bc9f0cf80cd4c5
    """

    @implicit
    fn __init__(out self, value: Self.dtype):
        self.value = value

    fn __init__(out self, enum: Self):
        self.value = enum.value


comptime DEFAULT_COLOR_SPACE = ColorSpace.RGB_24
