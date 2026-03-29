from momanim.animation.animation import Animatable


from momanim.mobject.geometry.polygram import Square


struct Create(Animatable):
    var obj: Some[AnyType]

    def __init__(out self, obj: Some[AnyType]):
        pass

    def __init__(out self, obj: Square) raises:
        self.obj = obj
