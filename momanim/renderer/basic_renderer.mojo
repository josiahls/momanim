from momanim.data_structs.video import Video
from momanim.scene.scene import Scenable
from momanim.camera.camera import Camera
from std.pathlib import Path


struct BasicRenderer[Scene: Scenable](Movable):
    var video: Video[DType.uint8]
    var scene: Self.Scene
    var camera: Camera
    var path: Path

    def __init__(out self, var scene: Self.Scene) raises:
        self.video = Video[DType.uint8]()
        self.scene = scene^
        self.camera = Camera()
        self.path = Path()

    fn render(self) raises:
        pass
