from momanim.typing import Vector3D
import numojo as nm


struct Square:
    var vertices: nm.NDArray[DType.float32]
    # var alphas: nm.NDArray[DType.float32]
    # var colors: nm.NDArray[DType.uint8]
    var color_fill: SIMD[DType.uint8, 4]

    def __init__(out self, color_fill: SIMD[DType.uint8, 4]) raises:
        self.vertices = nm.zeros[DType.float32]([4, 3])
        # self.vertices = nm.Matrix.fromstring[DType.float32](
        #     "[[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]]", shape=(4, 3)
        # ).to_ndarray()
        self.vertices = nm.Matrix.fromstring[DType.float32](
            "[[-10,-10,1],[10,-10,1],[10,10,1],[-10,10,1]]", shape=(4, 3)
        ).to_ndarray()

        self.color_fill = color_fill

    def compile_bezier(self):
        pass

        # [R, G, B, A]
        # self.colors = nm.zeros[DType.uint8]([4, 4])
        # self.colors.itemset([0, 0], 1.0)
        # self.colors.itemset([0, 1], 1.0)
        # self.colors.itemset([0, 2], 1.0)
        # self.colors.itemset([0, 3], 1.0)
        # self.colors.itemset([1, 0], 1.0)
        # self.colors.itemset([1, 1], 1.0)
        # self.colors.itemset([1, 2], 1.0)
        # self.colors.itemset([1, 3], 1.0)
        # self.colors.itemset([2, 0], 1.0)
        # self.colors.itemset([2, 1], 1.0)
        # self.colors.itemset([2, 2], 1.0)
        # self.colors.itemset([2, 3], 1.0)
        # self.colors.itemset([3, 0], 1.0)
        # self.colors.itemset([3, 1], 1.0)
        # self.colors.itemset([3, 2], 1.0)
        # self.colors.itemset([3, 3], 1.0)

    # def flip(self, direction: Vector3D) -> None:
    #     pass

    # def rotate(self, angle: Float32) -> None:
    #     pass
