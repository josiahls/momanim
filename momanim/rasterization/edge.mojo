from momanim.rasterization.fixed_point import (
    MaskImage,
    FixedInt,
    FixedPointEdge2d,
    XPixelSampling,
    YPixelSampling,
    FixedPoint48x16,
    FixedPointTrapezoid2d,
)
from std.math import align_up, align_down


def rasterize_edge(
    mut image: MaskImage,
    trapezoid: FixedPointTrapezoid2d,
):
    rasterize_edge(
        image,
        trapezoid.l,
        trapezoid.r,
        trapezoid.top,
        trapezoid.bot,
    )


@fieldwise_init
struct EdgeErrorTrackerAndStepper:
    var error: FixedInt
    var x: FixedInt
    var dx: FixedInt
    var dy: FixedInt
    var dx_small: FixedInt
    var dx_big: FixedInt
    var stepx_small: FixedInt
    var stepx_big: FixedInt
    var step_x: FixedInt
    var sign_dx: FixedInt

    def __init__(out self, edge: FixedPointEdge2d):
        var mag = edge.magnitude()
        self.x = edge.p0.x
        self.dy = mag.y
        if mag.x >= FixedInt.zero:
            self.sign_dx = FixedInt.e
            self.step_x = mag.x / mag.y
            self.dx = mag.x % mag.y
            self.error = mag.y * -1
        else:
            self.sign_dx = FixedInt.e * -1
            # NOTE: pixman used -(-mag.x / mag.y) since older archs
            # would be slower on negative nominators.
            self.step_x = mag.x / mag.y
            self.dx = -mag.x % mag.y
            self.error = FixedInt.zero

        self.dx_small = FixedInt.zero
        self.dx_big = FixedInt.zero
        self.stepx_small = FixedInt.zero
        self.stepx_big = FixedInt.zero

        Self.multi_init(
            self.dx,
            self.dy,
            self.step_x,
            self.sign_dx,
            Int(YPixelSampling.step_size),
            self.stepx_small,
            self.dx_small,
        )
        Self.multi_init(
            self.dx,
            self.dy,
            self.step_x,
            self.sign_dx,
            Int(YPixelSampling.remainder),
            self.stepx_big,
            self.dx_big,
        )

    @staticmethod
    def multi_init(
        dx: FixedInt,
        dy: FixedInt,
        step_x: FixedInt,
        sign_dx: FixedInt,
        y_steps: Int,
        mut x_step: FixedInt,
        mut dx_step: FixedInt,
    ):
        # Pixman `_pixman_edge_multi_init`: ne = n * dx, step_x_ = n * stepx,
        # then if ne > 0: nx = ne / dy; ne -= nx * dy; step_x += nx * signdx.
        var dx_i = Int(dx)
        var dy_i = Int(dy)
        var step_x_i = Int(step_x)

        var ne: FixedPoint48x16 = FixedPoint48x16(dx) * y_steps
        var step_x_ = step_x * y_steps

        if ne > FixedPoint48x16.zero:
            var dy_w = FixedPoint48x16(dy)
            var nx = ne / dy_w
            var ne_mid = nx * dy_w
            ne -= ne_mid
            var bump = nx * FixedPoint48x16(sign_dx)
            step_x_ += FixedInt(bump)
        else:
            print(
                "  ne<=0  skip nx branch (pixman leaves step_x_, ne as initial)"
            )

        x_step = step_x_
        dx_step = FixedInt(ne)

    def edge_step(mut self, n_units: FixedInt):
        """Pixman ``pixman_edge_step``: advance edge by Δy (`n_units`) in raw 16.16.
        """

        comptime I64 = Scalar[DType.int64]
        var n_raw = Int(n_units.value)

        var xv = I64(Int(self.x.value)) + I64(n_raw) * I64(
            Int(self.step_x.value)
        )
        var ne = I64(Int(self.error.value)) + I64(n_raw) * I64(
            Int(self.dx.value)
        )
        var dy_v = I64(Int(self.dy.value))

        if n_raw >= 0:
            if ne > 0:
                var nx_quot = Int((ne + dy_v - I64(1)) / dy_v)
                ne = ne - I64(nx_quot) * dy_v
                xv = xv + I64(nx_quot) * I64(Int(self.sign_dx.value))
                self.error = FixedInt(Scalar[DType.int32](Int(ne)))
        else:
            if ne <= -dy_v:
                var nx_neg = Int((-ne) / dy_v)
                ne = ne + I64(nx_neg) * dy_v
                xv = xv - I64(nx_neg) * I64(Int(self.sign_dx.value))
                self.error = FixedInt(Scalar[DType.int32](Int(ne)))

        self.x = FixedInt(Scalar[DType.int32](Int(xv)))

    def step_small(mut self):
        self.x += self.stepx_small
        self.error += self.dx_small
        if self.error > FixedInt.zero:
            # print("\terror", self.error)
            self.error -= self.dy
            self.x += self.sign_dx
            # print("\tx", self.x)

    def step_big(mut self):
        self.x += self.stepx_big
        self.error += self.dx_big
        if self.error > FixedInt.zero:
            self.error -= self.dy
            self.x += self.sign_dx


def rasterize_edge(
    mut image: MaskImage,
    edge_0: FixedPointEdge2d,
    edge_1: FixedPointEdge2d,
    top: FixedInt,
    bot: FixedInt,
):
    ref linesize = image.linesize
    var y_sample = YPixelSampling.ceil(top)
    var snap_bottom = YPixelSampling.floor(bot)
    var line = image.data + linesize * y_sample.to_real_int()
    print(
        "y_sample", y_sample, "top", top, "snap_bottom", snap_bottom, "bot", bot
    )
    var lx_sample: FixedInt
    var rx_sample: FixedInt

    var slope_0 = edge_0.magnitude()
    var slope_1 = edge_1.swap().magnitude()

    # print("initializing left edge")
    var l = EdgeErrorTrackerAndStepper(edge_0)
    var r = EdgeErrorTrackerAndStepper(edge_1.swap())

    var dy_to_first_scan = y_sample - top
    l.edge_step(dy_to_first_scan)
    r.edge_step(dy_to_first_scan)

    # slope_0.normalize_slope_()
    # slope_1.normalize_slope_()

    print(edge_0)
    print(edge_1)
    print(top)
    print(bot)

    # for iteration in range(10):
    while True:
        var lx: FixedInt = l.x
        var rx: FixedInt = r.x
        if lx.to_real_int() < 0:
            lx = FixedInt(0)
        if rx.to_real_int() >= image.width:
            rx = FixedInt(image.width - 1)

        # print("lx", lx, "rx", rx, "y_sample", y_sample)

        if rx > lx:
            var lxi = lx.to_real_int()
            var rxi = rx.to_real_int()

            var lxs = XPixelSampling.coverage(lx)
            var rxs = XPixelSampling.coverage(rx)

            if lxi == rxi:
                # TODO: Need to clip to 255 as the max value.
                line[lxi] = UInt8(
                    min(Int(255), Int(line[lxi]) + Int(rxs) - Int(lxs))
                )
                # print("line[lxi]", line[lxi], "lx", lx, "rx", rx, "y_sample", y_sample)
            else:
                line[lxi] = UInt8(
                    min(
                        Int(255),
                        Int(line[lxi])
                        + XPixelSampling.samples_per_pixel
                        - Int(lxs),
                    )
                )

                lxi += 1

                for i in range(rxi - lxi):
                    line[lxi + i] = UInt8(255)

                line[rxi] = UInt8(min(Int(255), Int(line[rxi]) + Int(rxs)))
                if y_sample.to_real_int() > 97:
                    print(
                        "line[rxi]",
                        line[rxi],
                        "lx",
                        lx,
                        "lxs",
                        lxs,
                        "rx",
                        rx,
                        "rxs",
                        rxs,
                        "y_sample",
                        y_sample,
                    )
        else:
            pass
            # print('skipping because rx <= lx', rx, lx)

        if y_sample >= snap_bottom:
            # print('breaking because y_sample >= bot', y_sample, bot)
            break

        # print("y_sample.fractional_part", y_sample.get_fractional_part(), "YPixelSampling.last_step_start", YPixelSampling.last_step_start)

        if y_sample.get_fractional_part() != YPixelSampling.last_step_start:
            y_sample = y_sample + YPixelSampling.step_size
            # print("lx", lx, "rx", rx, "y_sample", y_sample, "step_small", l.stepx_small, r.stepx_small)
            l.step_small()
            r.step_small()
        else:
            y_sample = y_sample + YPixelSampling.remainder
            if y_sample.to_real_int() > 97:
                print(
                    "lx",
                    lx,
                    "rx",
                    rx,
                    "y_sample",
                    y_sample,
                    "step_big",
                    l.stepx_big,
                    r.stepx_big,
                )
            l.step_big()
            r.step_big()

            line += linesize
            # print("line incrmented at y_sample", y_sample)

    # for i, point in enumerate(
    #     [edge_0.p0.copy(), edge_0.p1.copy(), edge_1.p0.copy(), edge_1.p1.copy()]
    # ):
    #     var y = point.y.to_real_int()
    #     var x = point.x.to_real_int()
    #     if y < 0:
    #         y = 0
    #     if y >= image.height:
    #         y = image.height - 1
    #     if x < 0:
    #         x = 0
    #     if x >= image.width:
    #         x = image.width - 1

    #     if i < 2:
    #         print("left", end=" ")
    #     else:
    #         print("right", end=" ")
    #     print("x: ", x, "y: ", y)
    #     var image_offset = linesize * y
    #     image.data[image_offset + x] = 255
    # while True:
    #     var lx = edge_0.p0.x
    #     var rx = edge_0.p0.x
    #     break
