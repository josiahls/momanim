from std.testing import TestSuite, assert_true
from std.time import perf_counter_ns

from momanim.pix_forge.perf.perf import Timer


def test_Timer() raises:
    """Timer is two perf_counter_ns reads plus a subtract.

    Expect tens of ns on this machine, not ms. That is fine for perf
    micro-benchmarks that measure strokes/fills over ~2s batches.
    """
    comptime samples = 100
    comptime max_avg_ns = 10_000  # 10µs; way above typical ~40ns, catches real regressions

    var timer_total: Int64 = 0
    var raw_total: Int64 = 0

    for _ in range(samples):
        var timer = Timer(start=True)
        timer.stop()
        timer_total += timer.elapsed()

        var start = perf_counter_ns()
        var stop = perf_counter_ns()
        raw_total += Int64(stop - start)

    # NOTE: Proves that the Timer struct does not introduce overhead.
    var timer_avg = timer_total // samples
    var raw_avg = raw_total // samples

    assert_true(timer_avg < max_avg_ns)
    assert_true(raw_avg < max_avg_ns)
    assert_true(
        abs(timer_avg - raw_avg) < 1_000,
        "Timer should match hand-rolled perf_counter_ns within ~1µs",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
