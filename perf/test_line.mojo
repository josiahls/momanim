from std.testing import TestSuite

from std.time import sleep

from momanim.pix_forge.perf.perf import Perf, perf_run, PerfTime
from momanim.pix_forge.context import PixForgeContext

def horizontal_hair(context: PixForgeContext, width: Int, height: Int, loops: Int) raises -> PerfTime:
    sleep(0.1)
    return 1

 

def line(mut perf: Perf, context: PixForgeContext, width: Int, height: Int) raises:

    perf_run(perf, "line-hh", horizontal_hair)
    

def main() raises:
    var perf = Perf()
    var context = PixForgeContext()
    line(perf, context, 16, 16)