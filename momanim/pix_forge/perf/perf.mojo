"""



Reference implementation is taken from Cairo's perf tooling:

- https://gitlab.freedesktop.org/cairo/cairo.git commit 8e3ac5

"""

from std.io.file import FileHandle
from std.time import sleep, perf_counter_ns
from std.logger.logger import Logger, DEFAULT_LEVEL

from momanim.pix_forge.context import PixForgeContext

comptime PerfTime = Int64


comptime logger = Logger()


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


@fieldwise_init
struct Target(Copyable):
    var name: String
    var basename: StaticString
    var file_extension: StaticString


struct PerfColumn(Copyable, Movable):
    var name: StaticString
    var prefix: String
    var postfix: String
    var value_width: Int
    var after_padding: Int

    def __init__(
        out self,
        name: StaticString,
        value_width: Int,
        prefix: StaticString = "",
        postfix: StaticString = "",
        after_padding: Int = 1,
    ):
        self.name = name
        self.prefix = prefix
        self.postfix = postfix
        self.value_width = value_width
        self.after_padding = after_padding

    def header(self, mut w: Some[Writer]):
        var value_width = max(self.value_width, self.name.count_codepoints())
        var col_width = (
            self.prefix.count_codepoints()
            + value_width
            + self.postfix.count_codepoints()
            + self.after_padding
        )
        w.write(self.prefix)
        w.write(self.name.ascii_rjust(value_width, " "))
        col_width = (
            col_width
            - self.prefix.count_codepoints()
            - value_width
            - self.postfix.count_codepoints()
        )
        w.write(self.postfix)
        w.write(" " * col_width)

    def row(self, mut w: Some[Writer], val: Some[Writable]):
        var s = String(val)
        var value_width = max(
            self.value_width, s.count_codepoints(), self.name.count_codepoints()
        )

        var col_width = (
            self.prefix.count_codepoints()
            + value_width
            + self.postfix.count_codepoints()
            + self.after_padding
        )

        w.write(self.prefix)
        w.write(s.ascii_rjust(value_width, " "))
        col_width = (
            col_width
            - self.prefix.count_codepoints()
            - value_width
            - self.postfix.count_codepoints()
        )
        w.write(self.postfix)
        w.write(" " * col_width)


comptime SummaryColumns = [
    PerfColumn("#", 3, prefix="[", postfix="]"),
    PerfColumn("backend.content", 12),
    PerfColumn("test-size", 28),
    PerfColumn("ticks-per-ms", 1),
    PerfColumn("time(ticks)", 1),
    PerfColumn("min(ticks)", 1),
    PerfColumn("min(ms)", 1),
    PerfColumn("median(ms)", 1),
    PerfColumn("stddev.", 1),
    PerfColumn("iterations", 1),
    PerfColumn("overhead", 1),
]


def _make_map() -> Dict[StaticString, PerfColumn]:
    var d = Dict[StaticString, PerfColumn]()
    comptime for col in SummaryColumns:
        d[col.name] = materialize[col]()
    return d^


comptime SummaryColumnMap = _make_map()


@fieldwise_init
struct SummaryHeader[o: Origin[mut=False]](Writable):
    var perf: Pointer[Perf, Self.o]

    def __init__(out self, ref[Self.o] perf: Perf):
        self.perf = Pointer(to=perf)

    def write_to(self, mut w: Some[Writer]):
        comptime for col in SummaryColumns:
            materialize[col]().header(w)


@fieldwise_init
struct SummaryRow[o: Origin[mut=False]](Writable):
    var perf: Pointer[Perf, Self.o]

    def __init__(out self, ref[Self.o] perf: Perf):
        self.perf = Pointer(to=perf)

    def write_to(self, mut w: Some[Writer]):
        ref perf = self.perf[]
        if perf.target:
            var column_map = materialize[SummaryColumnMap]()
            ref target = perf.target.unsafe_value()
            try:
                column_map["#"].row(w, perf.test_number)
                column_map["backend.content"].row(w, "someimage")
                column_map["test-size"].row(w, perf.size)
                column_map["ticks-per-ms"].row(w, 0.0)
                column_map["time(ticks)"].row(w, 0.0)
                column_map["min(ticks)"].row(w, 0.0)
                column_map["min(ms)"].row(w, 0.0)
                column_map["median(ms)"].row(w, 0.0)
                column_map["stddev."].row(w, 0.0)
                column_map["iterations"].row(w, perf.iterations)
                column_map["overhead"].row(w, 0.0)
            except e:
                w.write("formatting failure: ", String(e))


struct Perf(Movable, Writable):
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
    var target: Optional[Target]
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

    def summary_row(self, mut writer: Some[Writer]) -> String:
        if self.target:
            ref target = self.target.unsafe_value()
            var s = String("")  # We probabaly should just use the writer (?)
            comptime for col in SummaryColumns:
                s += String(col.name)
            return s

        return ""

        # comptime for col in SummaryColumns:
        #     writer.write(col.name)
        # if self.target:
        #     ref target = self.target.unsafe_value()
        #     return Self.SummaryString.format(
        #         self.test_number,
        #         "someimage",
        #         target.name,
        #         0.0,
        #         0.0,
        #         0.0,
        #         0.0,
        #         0.0,
        #         0.0,
        #         0.0,
        #         0.0,
        #         0.0,
        #         0.0,
        #         0.0,
        #         0.0,
        #         0.0

        #     )
        # else:
        #     return ""

    def summary_header(self, mut writer: Some[Writer]):
        comptime for col in SummaryColumns:
            writer.write(col.name)
        # writer.write(
        #     Self.SummaryString.format(
        #         " # ",
        #         "backend.content",
        #         " " * 28,
        #         "test-size",
        #         " " * 8,
        #         "ticks-per-ms",
        #         " " * 8,
        #         "time(ticks)",
        #         " " * 5,
        #         "min(ticks)",
        #         " " * 5,
        #         "min(ms)",
        #         "median(ms)",
        #         "stddev.",
        #         "iterations",
        #         "overhead"
        #     )
        # )

    def register_target(mut self, name: StaticString):
        self.target = Target(
            name="{}.{}".format(name, self.size),
            basename=name,
            file_extension="",
        )


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
    perf.register_target(name)

    var time = perf_func(perf.context, perf.size, perf.size, perf.iterations)
    # logger.debug("Warming up: ", name)
    perf.times.append(time)

    logger.info(SummaryRow(perf))
