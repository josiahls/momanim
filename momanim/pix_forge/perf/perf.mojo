"""



Reference implementation is taken from Cairo's perf tooling:

- https://gitlab.freedesktop.org/cairo/cairo.git commit 8e3ac5

"""

from std.io.file import FileHandle
from std.time import sleep, perf_counter_ns
from std.logger.logger import Logger, DEFAULT_LEVEL
from std.algorithm.reduction import mean
from std.math import sqrt

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
    PerfColumn("min(ticks)", 12),
    PerfColumn("min(ticks) = min(batch) / loops", 28, prefix="[", postfix="]"),
    PerfColumn("min(ms)", 12),
    PerfColumn("median(ms)", 12),
    PerfColumn("stddev.", 6),
    PerfColumn("batches", 2),
    PerfColumn("overhead", 2),
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


struct SummaryStats:
    var min_ticks: PerfTime
    var median_ticks: PerfTime
    var std_dev: Float64
    var batches: Int
    var values: List[PerfTime]

    def __init__(out self, var values: List[PerfTime]):
        var num_values = len(values)
        assert num_values > 0

        self.min_ticks = values[0]
        self.median_ticks = values[0]
        self.std_dev = 0
        self.batches = 1
        if num_values == 1:
            self.values = values^
            return

        var values_ptr = values.steal_data()

        # NOTE: Comment taken from:
        # https://gitlab.freedesktop.org/cairo/cairo.git 8e3ac5e4
        # First, identify any outliers, using the definition of "mild
        # outliers" from:
        #
        # 		http://en.wikipedia.org/wiki/Outliers
        #
        # Which is that outliers are any values less than Q1 - 1.5 * IQR
        # or greater than Q3 + 1.5 * IQR where Q1 and Q3 are the first
        # and third quartiles and IQR is the inter-quartile range (Q3 -
        # Q1).
        var num_valid = num_values
        var starting_num_valid = num_values
        var q1: PerfTime
        var q3: PerfTime
        var iqr: PerfTime
        var outlier_min: PerfTime
        var outlier_max: PerfTime
        var min_valid: Int
        var i: Int = -1
        sort(Span(ptr=values_ptr, length=num_values))

        while num_valid != num_values or i == -1:
            # NOTE: Expanding on above, this is specifically Tukey's fences
            q1 = values_ptr[1 * num_values / 4]
            q3 = values_ptr[3 * num_values / 4]
            iqr = q3 - q1  # inter quartile range
            outlier_min = q1 - 3 * iqr / 2
            outlier_max = q3 + 3 * iqr / 2
            i = 0
            while i < num_values and values_ptr[i] < outlier_min:
                i += 1

            min_valid = i

            i = 0
            while i < num_values and values_ptr[i] <= outlier_max:
                i += 1

            num_valid = i - min_valid
            assert num_valid != 0, "Unable to find any valid stats."
            values_ptr += min_valid
            logger.debug(
                "SummaryStat Refinement: ",
                t"q1={q1},q3={q3},iqr={iqr},outlier_min={outlier_min}",
                t"outlier_max={outlier_max},(original)num_valid={starting_num_valid}",
                t"(narrowed)num_valid={num_valid}",
            )

        self.values = List[PerfTime](capacity=num_valid)
        for i in range(num_valid):
            self.values.append(values_ptr[i])

        self.batches = num_valid
        self.min_ticks = self.values[0]
        self.median_ticks = self.values[num_valid / 2]

        def std_dev(values: List[PerfTime]) -> Float64:
            try:
                var mean_ticks = Float64(mean(values))

                def delta(v: PerfTime) -> Float64:
                    return (Float64(v) - mean_ticks) / mean_ticks

                var deltas = List[Float64](capacity=len(values))
                for v in values:
                    deltas.append(delta(v) ** 2)

                assert len(deltas) > 0, "No deltas to calculate std dev."
                return sqrt(mean(deltas))
            except e:
                logger.warning("Stat calc failed: ", e)
                return 0

        self.std_dev = std_dev(self.values)

    @staticmethod
    def ticks_to_ms(v: PerfTime) -> PerfTime:
        # TODO: should this be Float64?
        return PerfTime(v / 100_000)


@fieldwise_init
struct SummaryRow[o1: Origin[mut=False], o2: Origin[mut=False]](Writable):
    var perf: Pointer[Perf, Self.o1]
    var stats: Pointer[SummaryStats, Self.o2]

    def __init__(
        out self, ref[Self.o1] perf: Perf, ref[Self.o2] stats: SummaryStats
    ):
        self.perf = Pointer(to=perf)
        self.stats = Pointer(to=stats)

    def tick_to_ms(self, tick: PerfTime) -> Float64:
        return Float64(tick) / 1000000.0

    def write_to(self, mut w: Some[Writer]):
        ref perf = self.perf[]
        if perf.target:
            var column_map = materialize[SummaryColumnMap]()
            ref target = perf.target.unsafe_value()
            try:
                var min_ticks = self.stats[].min_ticks
                var median_ticks = self.stats[].median_ticks
                column_map["#"].row(w, perf.test_number)
                column_map["backend.content"].row(w, "someimage")
                column_map["test-size"].row(w, target.name)
                column_map["min(ticks)"].row(w, min_ticks)
                column_map["min(ticks) = min(batch) / loops"].row(
                    w, "{} / {}".format(min_ticks, perf.loops)
                )
                column_map["min(ms)"].row(
                    w, SummaryStats.ticks_to_ms(min_ticks)
                )
                column_map["median(ms)"].row(
                    w, SummaryStats.ticks_to_ms(median_ticks)
                )
                column_map["stddev."].row(w, round(self.stats[].std_dev, 3))
                column_map["batches"].row(w, perf.batches)
                column_map["overhead"].row(w, "na")
            except e:
                w.write("formatting failure: ", String(e))


struct Perf(Movable, Writable):
    var summary: Optional[FileHandle]
    var summary_continuous: Bool

    # CLI options
    var batches: Int
    var exact_batches: Bool
    var raw: Bool
    var list_only: Bool
    var observe: Bool
    var names: List[StaticString]
    var exlude_names: List[StaticString]
    var exact_names: Bool

    var ms_per_batch: Float64
    var fast_and_sloppy: Bool

    var tile_size: Int

    # Interal
    var times: List[PerfTime]
    var targets: List[Target]
    var target: Optional[Target]
    # TODO: I think this is the current active target
    var test_number: Int
    var size: Int
    var loops: Int
    # NOTE: Tried using Pointer, but passing the context from Perf into
    # subfunctions / perf functions was not possible do to the
    # origins.
    var context: UnsafePointer[PixForgeContext, MutExternalOrigin]

    def __init__(
        out self, var context: PixForgeContext, fast_and_sloppy: Bool = False
    ):
        self.summary = None
        self.summary_continuous = False

        # CLI options
        self.batches = 10
        self.exact_batches = False
        self.raw = False
        self.list_only = False
        self.observe = False
        self.names = List[StaticString]()
        self.exlude_names = List[StaticString]()
        self.exact_names = False

        # Maximum ms allowable per batch.
        self.ms_per_batch = 2000
        self.fast_and_sloppy = fast_and_sloppy

        self.tile_size = 0

        self.times = List[PerfTime]()
        self.targets = List[Target]()
        self.target = None
        self.test_number = 0
        self.size = 0
        self.loops = 0
        self.context = UnsafePointer(to=context).unsafe_origin_cast[
            MutExternalOrigin
        ]()

    def register_target(mut self, name: StaticString):
        self.target = Target(
            name="{}.{}".format(name, self.size),
            basename=name,
            file_extension="",
        )


comptime PerfFunc = def(
    mut context: UnsafePointer[PixForgeContext, MutExternalOrigin],
    width: Int,
    height: Int,
    loops: Int,
) raises -> PerfTime


def perf_calibrate(mut perf: Perf, perf_func: PerfFunc) raises -> Int:
    var loops: Int
    var min_loops: Int = 1
    var calibration = perf_func(perf.context, perf.size, perf.size, min_loops)

    if not perf.fast_and_sloppy:
        var calibration_max: PerfTime
        # Divde into quartiles.
        # TODO: not sure what the 0.0001 is needed for?
        calibration_max = PerfTime(perf.ms_per_batch * 0.0001 / 4)
        while calibration < calibration_max:
            min_loops *= 2
            calibration = perf_func(
                perf.context, perf.size, perf.size, min_loops
            )

    # NOTE: Comment taken from:
    # https://gitlab.freedesktop.org/cairo/cairo.git 8e3ac5e4
    # Compute the number of loops required for the timing
    # interval to be perf->ms_per_iteration milliseconds. This
    # helps to eliminate sampling variance due to timing and
    # other systematic errors.  However, it also hides
    # synchronisation overhead as we attempt to process a large
    # batch of identical operations in a single shot. This can be
    # considered both good and bad... It would be good to perform
    # a more rigorous analysis of the synchronisation overhead,
    # that is to estimate the time for loop=0.

    # NOTE: Cairo has a strange int64 vs int casting.
    loops = Int(
        perf.ms_per_batch * 0.001 * Float64(min_loops) / Float64(calibration)
    )
    min_loops = 1 if perf.fast_and_sloppy else 10
    if loops < min_loops:
        loops = min_loops

    return loops


def perf_run(
    mut perf: Perf,
    name: StaticString,
    perf_func: PerfFunc,
) raises:
    perf.register_target(name)

    logger.debug("Warming up: ", name)
    var time = perf_func(perf.context, perf.size, perf.size, perf.batches)
    logger.debug("Calibrating: ", name)
    perf.loops = perf_calibrate(perf, perf_func)

    logger.debug("Executing: ", name)
    for b in range(perf.batches):
        time = perf_func(perf.context, perf.size, perf.size, perf.loops)
        perf.times.append(time)

    var stats = SummaryStats(perf.times.copy())

    logger.info(SummaryRow(perf, stats))
