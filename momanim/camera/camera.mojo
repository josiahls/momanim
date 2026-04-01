from momanim.typing import Vector3D
from momanim.constants import ORIGIN


struct Camera(Copyable, ImplicitlyCopyable):
    var pixel_height: UInt
    var pixel_width: UInt

    var position: Vector3D
    var focal_length: Float32

    def __init__(out self, pixel_height: UInt, pixel_width: UInt):
        self.pixel_height = pixel_height
        self.pixel_width = pixel_width
        self.focal_length = 1.0
        self.position = ORIGIN
        self.position[2] = 1.0
