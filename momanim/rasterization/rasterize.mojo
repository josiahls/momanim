from momanim.rasterization.image import MaskImage
from momanim.rasterization.geometry_2d import (
    FixedPointEdge2d,
)
from momanim.rasterization.fixed_point_trap_2d import FixedPointTrap2d

from momanim.rasterization.subpixel_sampling import (
    XPixelSampling,
    YPixelSampling,
)
from momanim.rasterization.fixed_dtype import FixedInt, FixedPoint48x16
from std.math import align_up, align_down
from momanim.rasterization.walkers import Edge2dWalker


def rasterize_edge(
    mut image: MaskImage,
    trapezoid: FixedPointTrap2d,
):
    rasterize_edge(
        image,
        trapezoid.l,
        trapezoid.r,
        trapezoid.top,
        trapezoid.bot,
    )


def rasterize_edge(
    mut image: MaskImage,
    edge_l: FixedPointEdge2d,
    edge_r: FixedPointEdge2d,
    var top: FixedInt,
    var bot: FixedInt,
):
    top = top if top >= FixedInt.zero else FixedInt.zero
    var y = YPixelSampling.ceil(top)
    if Int(bot) >= Int(image.height):
        bot = FixedInt(from_int=image.height - 1)
    var snap_bot = YPixelSampling.floor(bot)
    var stride = image.line_size
    var width = image.width
    var height = image.height
    var fill_start = -1
    var fill_end = -1
    var fill_size = 0
    var line = image.buffer + Int(y) * stride
    # print("edge_l", edge_l)
    # print("edge_r", edge_r)
    # print("swapped_edge_r", swapped_edge_r)

    var l = Edge2dWalker(edge_l, y)
    # NOTE: l and r are together rotating CCW. swap the r points so both
    # point from top y to bot y.
    var r = Edge2dWalker(edge_r.swap(), y)
    var start_y = y - top
    # TODO: Wonder if this could be SIMD.
    # print("moving to start y", start_y, " (", Float64(start_y), ")")
    # print(
    #     "y: ",
    #     y,
    #     "(",
    #     Float64(y),
    #     ")",
    #     " top: ",
    #     top,
    #     " (",
    #     Float64(top),
    #     ")",
    #     " bot: ",
    #     bot,
    #     " (",
    #     Float64(bot),
    #     ")",
    # )
    # l.step_n_units(start_y)
    # r.step_n_units(start_y)

    # TODO: We should be able to have this as a for loop no?
    while True:
        var lx = l.x
        var rx = r.x
        # print("initial lx: ", lx, "rx: ", rx)
        if lx < 0:
            lx = 0
        if Int(FixedInt(raw_value=rx)) >= image.width:
            rx = r.IntType(FixedInt(from_int=image.width - 1).value)

        # print("lx: ", lx, "rx: ", rx)

        if rx > lx:
            var lxi = Int(FixedInt(raw_value=lx))
            var rxi = Int(FixedInt(raw_value=rx))
            var lxs = XPixelSampling.coverage(FixedInt(raw_value=lx))
            var rxs = XPixelSampling.coverage(FixedInt(raw_value=rx))
            # print("lxs: ", lxs, "rxs: ", rxs)
            # print("lxi: ", lxi, "rxi: ", rxi)
            # print("drawing line from ", lxi, " to ", rxi)

            # print("line (before drawing): ", end=" ")
            # for i in range(lxi, rxi):
            #     print(line[i], end=" ")
            # print()

            if lxi == rxi:
                line[lxi] = UInt8(
                    min(Int(255), Int(line[lxi]) + Int(rxs) - Int(lxs))
                )
            else:
                line[lxi] = UInt8(
                    min(
                        Int(255),
                        Int(line[lxi])
                        + XPixelSampling.samples_per_axis
                        - Int(lxs),
                    )
                )
                lxi += 1
                # TODO: pixman has a if statement: if (rxi - lxi > 4)
                # that does a write optimziation. We can revisit this when trying
                # to optimize since Mojo should make it far cleaner via SIMD.
                for i in range(rxi - lxi):
                    line[lxi + i] = UInt8(
                        min(
                            Int(255),
                            Int(line[lxi + i])
                            + Int(XPixelSampling.samples_per_axis),
                        )
                    )
                line[rxi] = UInt8(min(Int(255), Int(line[rxi]) + Int(rxs)))

        if y >= snap_bot:
            break

        if y.frac() != YPixelSampling.last_step_start:
            y = y + YPixelSampling.step_size
            l.step()
            r.step()
            # print("### Y step")
        else:
            y = y + YPixelSampling.step_remainder
            l.step_remainder()
            r.step_remainder()

            line += stride
            # print('stopping early')
            # break
