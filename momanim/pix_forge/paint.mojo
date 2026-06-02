from momanim.pix_forge.surface import (
    Surfaceable,
    ColorSurface,
    SolidSurface,
    _fill_buffer,
)


# TODO: Handle resolution up/down sampling.
# TODO: Note this module assumes RGBA or A8 always.


def paint[
    batch_size: Int = 64
](mut target: ColorSurface, pattern: SolidSurface):
    _fill_buffer[batch_size=batch_size](
        target.buffer,
        pattern.buffer.unsafe_ptr()[],
        target.size,
        "Paint failed to fill the buffer!",
    )
