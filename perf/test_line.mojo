from std.testing import TestSuite

from std.time import sleep, perf_counter_ns

from momanim.pix_forge.perf.perf import Perf, perf_run, PerfTime, Timer, SummaryRow, SummaryHeader
from std.logger.logger import Logger, DEFAULT_LEVEL
from momanim.pix_forge.context import PixForgeContext


comptime ContextPtr = UnsafePointer[PixForgeContext, MutExternalOrigin]


comptime logger = Logger()


def horizontal(
    context: ContextPtr, width: Int, height: Int, loops: Int
) -> PerfTime:
    var h = Float64(height) / 2.0 + 0.5
    # move_to( context, 0, h)
    # line_to( context, width ,h)

    var timer = Timer(start=True)

    for _ in range(loops):
        sleep(0.1)
        # stroke_presserve
        pass

    timer.stop()
    # new_path

    return timer.elapsed()


def horizontal_hair(mut context: ContextPtr, width: Int, height: Int, loops: Int) raises -> PerfTime:
    sleep(0.1)
    return horizontal(context, width, height, loops)

 

def line(mut perf: Perf, width: Int, height: Int) raises:

    perf_run(perf, "line-hh", horizontal_hair)
    

def main() raises:
    var context = PixForgeContext()
    var perf = Perf(context=context^)
    logger.info(SummaryHeader(perf))
    perf.size=16
    line(perf, perf.size, perf.size)

