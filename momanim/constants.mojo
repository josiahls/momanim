from momanim.stdlib_extensions import Enumable
from momanim.typing import Vector3D
from std.math import pi, tau


struct ColorSpace(Enumable):
    comptime dtype = Int
    var value: Self.dtype

    comptime UNSPECIFIED = Self(0)

    comptime RGB_24 = Self(1)
    """Packed RGB 8:8:8, 24bpp, RGBRGB...
    """
    comptime RGBA_32 = Self(2)
    """Packed RGBA 8:8:8:8, 32bpp, RGBARGBA...

    Contiains an alpha channel.

    Default for `momanim`. 
    """
    comptime YUV_420P = Self(3)
    """Planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples).
    
    Defualt in ffmpeg (at least their examples)
    - https://ffmpeg.org//doxygen/trunk/pixfmt_8h.html#a9a8e335cf3be472042bc9f0cf80cd4c5
    """

    @implicit
    fn __init__(out self, value: Self.dtype):
        self.value = value

    fn __init__(out self, enum: Self):
        self.value = enum.value


comptime DEFAULT_COLOR_SPACE = ColorSpace.RGBA_32


comptime ORIGIN: Vector3D = [0.0, 0.0, 0.0]
"""The center of the coordinate system."""

comptime UP: Vector3D = [0.0, 1.0, 0.0]
"""One unit step in the positive Y direction."""

comptime DOWN: Vector3D = [0.0, -1.0, 0.0]
"""One unit step in the negative Y direction."""

comptime RIGHT: Vector3D = [1.0, 0.0, 0.0]
"""One unit step in the positive X direction."""

comptime LEFT: Vector3D = [-1.0, 0.0, 0.0]
"""One unit step in the negative X direction."""

comptime IN: Vector3D = [0.0, 0.0, -1.0]
"""One unit step in the negative Z direction."""

comptime OUT: Vector3D = [0.0, 0.0, 1.0]
"""One unit step in the positive Z direction."""

# Geometry: axes
comptime X_AXIS: Vector3D = [1.0, 0.0, 0.0]
comptime Y_AXIS: Vector3D = [0.0, 1.0, 0.0]
comptime Z_AXIS: Vector3D = [0.0, 0.0, 1.0]

# Geometry: useful abbreviations for diagonals
comptime UL: Vector3D = UP + LEFT
"""One step up plus one step left."""

comptime UR: Vector3D = UP + RIGHT
"""One step up plus one step right."""

comptime DL: Vector3D = DOWN + LEFT
"""One step down plus one step left."""

comptime DR: Vector3D = DOWN + RIGHT
"""One step down plus one step right."""

# Geometry
comptime START_X: Float32 = 30.0
comptime START_Y: Float32 = 20.0
comptime DEFAULT_DOT_RADIUS: Float32 = 0.08
comptime DEFAULT_SMALL_DOT_RADIUS: Float32 = 0.04
comptime DEFAULT_DASH_LENGTH: Float32 = 0.05
comptime DEFAULT_ARROW_TIP_LENGTH: Float32 = 0.35

# Default buffers (padding)
comptime SMALL_BUFF: Float32 = 0.1
comptime MED_SMALL_BUFF: Float32 = 0.25
comptime MED_LARGE_BUFF: Float32 = 0.5
comptime LARGE_BUFF: Float32 = 1.0
comptime DEFAULT_MOBJECT_TO_EDGE_BUFFER: Float32 = MED_LARGE_BUFF
comptime DEFAULT_MOBJECT_TO_MOBJECT_BUFFER: Float32 = MED_SMALL_BUFF

# Times in seconds
comptime DEFAULT_POINTWISE_FUNCTION_RUN_TIME: Float32 = 3.0
comptime DEFAULT_WAIT_TIME: Float32 = 1.0

# Misc
comptime DEFAULT_POINT_DENSITY_2D: Int = 25
comptime DEFAULT_POINT_DENSITY_1D: Int = 10
comptime DEFAULT_STROKE_WIDTH: Int = 4
comptime DEFAULT_FONT_SIZE: Int = 48
comptime SCALE_FACTOR_PER_FONT_POINT: Float32 = 1 / 960.0


comptime DEGREES = tau / 360.0
"""The exchange rate between radians and degrees."""


comptime CACHE_LINE_SIZE: Int = 64
"""Modern CPUs typically use cache lines of 64 bytes."""
