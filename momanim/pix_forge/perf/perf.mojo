"""



Reference implementation is taken from Cairo's perf tooling:

- https://gitlab.freedesktop.org/cairo/cairo.git commit 8e3ac5

"""

from std.io.file import FileHandle
from std.time import sleep, perf_counter_ns

from momanim.pix_forge.context import PixForgeContext

comptime PerfTime = Int64


struct Timer(Movable):
    # TODO: How much do we need to do to prove this works?
    var start_ns: UInt
    var stop_ns: UInt

    def __init__(out self, start: Bool = False):
        self.stop_ns = -1
        self.start_ns = -1
        if start:
            self.start()

    @always_inline
    def start(mut self):
        self.start_ns = perf_counter_ns()

    @always_inline
    def stop(mut self):
        assert self.start_ns >= 0
        self.stop_ns = perf_counter_ns()

    def elapsed(self) -> PerfTime:
        assert self.start_ns >= 0
        assert self.stop_ns >= 0
        return PerfTime(self.stop_ns - self.start_ns)


struct Target(Copyable):
    var name: StaticString
    var basename: StaticString
    var file_extension: StaticString


struct Perf:
    var summary: Optional[FileHandle]
    var summary_continuous: Bool

    # CLI options
    var iterations: Int
    var exact_iterations: Bool
    var raw: Bool
    var list_only: Bool
    var observe: Bool
    var names: List[StaticString]
    var exlude_names: List[StaticString]
    var exact_names: Bool

    var ms_per_iteration: Float64
    var fast_and_sloopy: Bool

    var tile_size: Int

    # Interal
    var times: List[PerfTime]
    var targets: List[Target]
    var target: Optional[UnsafePointer[Target, MutExternalOrigin]]
    # TODO: I think this is the current active target
    var test_number: Int
    var size: Int
    # NOTE: Tried using Pointer, but passing the context from Perf into
    # subfunctions / perf functions was not possible do to the
    # origins.
    var context: UnsafePointer[PixForgeContext, MutExternalOrigin]

    def __init__(out self, var context: PixForgeContext):
        self.summary = None
        self.summary_continuous = False

        # CLI options
        self.iterations = 10
        self.exact_iterations = False
        self.raw = False
        self.list_only = False
        self.observe = False
        self.names = List[StaticString]()
        self.exlude_names = List[StaticString]()
        self.exact_names = False

        self.ms_per_iteration = 0.0
        self.fast_and_sloopy = False

        self.tile_size = 0

        self.times = List[PerfTime]()
        self.targets = List[Target]()
        self.target = None
        self.test_number = 0
        self.size = 0
        self.context = UnsafePointer(to=context).unsafe_origin_cast[
            MutExternalOrigin
        ]()


def perf_run(
    mut perf: Perf,
    name: StaticString,
    perf_func: def(
        mut context: UnsafePointer[PixForgeContext, MutExternalOrigin],
        width: Int,
        height: Int,
        loops: Int,
    ) raises -> PerfTime,
) raises:
    var time = perf_func(perf.context, perf.size, perf.size, 1)
    perf.times.append(time)
