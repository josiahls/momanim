from std.testing import TestSuite

from std.time import sleep, perf_counter_ns

from momanim.pix_forge.perf.perf import Perf, perf_run, PerfTime, Timer, SummaryRow, SummaryHeader
from std.logger.logger import Logger, DEFAULT_LEVEL
from momanim.pix_forge.context import PixForgeContext


comptime ContextPtr = UnsafePointer[PixForgeContext, MutExternalOrigin]


comptime logger = Logger()


def do_paint(
    context: ContextPtr, width: Int, height: Int, loops: Int
) -> PerfTime:

    var timer = Timer(start=True)

    for _ in range(loops):
        sleep(0.1)
        # Should do third_party/cairo/src/cairo-gstate.c:_cairo_gstate_paint
        # third_party/cairo/src/cairo-surface.c
        # which then does `_cairo_surface_paint`
        # paint(context)
        pass

    timer.stop()

    return timer.elapsed()


def count_paint(context: ContextPtr, width: Int, height: Int) -> Float64:
    return Float64(width * height) / 1e6 # Mpix/s



def init_and_set_source_surface(context: ContextPtr, source: ImageSurfacePtr, width: Int, height: Int) raises:

    var cr2 = Context(source)
    cr2.set_operator(CAIRO_OPERATOR_SOURCE)
    cr2.set_source_rgb(0, 0, 1)
    cr2.paint()
    cr2.set_source_rgba(1, 0, 0, 0.5)
    cr2.new_path()
    cr2.rectangle(0, 0, width/2.0, height/2.0)
    cr2.rectangle(width/2.0, height/2.0, width/2.0, height/2.0)
    cr2.fill()

    context[].set_source_surface(source, 0, 0)


def set_source_image_surface_rgb(context: ContextPtr, width: Int, height: Int) raises:
    # NOTE: This is a combination of 
    # cairo_operator_t and sources.
    var surface = ColorSurface(CAIRO_FORMAT_RGB24, width, height)
    context[].set_source_image_surface_rgb(source, width, height)
    context[].set_operator("source")


def paint(mut perf: Perf, width: Int, height: Int) raises:
    perf_run(perf, "image-rgb", set_source_image_surface_rgb)

    # perf_cover_sources_and_operators(perf, "paint", do_paint, count_paint)
    

def main() raises:
    var context = PixForgeContext()
    var perf = Perf(context=context^)
    logger.info(SummaryHeader(perf))
    perf.size=64
    paint(perf, perf.size, perf.size)

