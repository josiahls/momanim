### Actual behavior

Compiling or running a small program that uses nested `comptime for` loops and indexes an `InlineArray` with `points[i + 1]` while `i` runs `0 ..< size` fails during compile-time evaluation. The diagnostic does not state that the index is out of bounds.

The compiler reports a long chain ending in:

- `failed to compile-time evaluate function call` on the inner `comptime for` line
- `failed to interpret function` … `_index_normalization::normalize_index` … `InlineArray`
- `failed to interpret function` … `debug_assert` …
- `interpreting memcpy can't get dst memory from the interpreter`
- `error: failed to run the pass manager`

Example (trimmed) from `pixi run mojo run repros/minimal_comptime_inlinearray_oob.mojo`:

```text
.../minimal_comptime_inlinearray_oob.mojo:7:18: note: failed to compile-time evaluate function call
        comptime for _r in range(1, size):
                 ^
...
oss/modular/mojo/stdlib/std/sys/intrinsics.mojo:68:10: note: interpreting memcpy can't get dst memory from the interpreter
.../mojo: error: failed to run the pass manager
```

**Root cause in user code:** `i` takes the value `size - 1` on the last iteration of `range(size)`, so `points[i + 1]` is `points[size]`, which is one past the last valid index for `InlineArray[..., size]`. The failure is an out-of-bounds access at comptime, but that is not spelled out in the error.

### Expected behavior

A direct, source-level error for the bad index, for example:

- A message that index `size` is out of bounds for `InlineArray` of length `size`, and/or
- A pointer to the offending expression `points[i + 1]` (or `i + 1`) and the loop that makes `i` equal `size - 1`.

Avoid surfacing low-level interpreter failures (`memcpy`, pass manager) as the primary diagnostic when the underlying issue is a comptime bounds violation.

---

### Minimal reproduction

Save as `minimal_comptime_inlinearray_oob.mojo` (included in this repo as [`repros/minimal_comptime_inlinearray_oob.mojo`](./minimal_comptime_inlinearray_oob.mojo)):

```mojo
# Minimal repro: comptime loop uses i in range(size) and indexes points[i + 1].
# When i == size - 1, that is out of bounds.

def oob_at_comptime[size: Int](points: InlineArray[Float32, size]) -> Float32:
    comptime for i in range(size):
        comptime for _r in range(1, size):
            _ = points[i]
            _ = points[i + 1]  # when i == size - 1, index is `size` — invalid
    return points[0]


def main():
    var pts: InlineArray[Float32, 4] = [0.0, 1.0, 2.0, 3.0]
    _ = oob_at_comptime(pts)
```

### Command line

From the repository root (with Mojo available via pixi, as in this project):

```bash
pixi run mojo run repros/minimal_comptime_inlinearray_oob.mojo
```

### Original context (larger codebase)

The same class of failure appeared while implementing Farin’s rational De Casteljau: an outer `comptime for i in range(size)` combined with `points[i + 1]` inside nested comptime loops. The comment in source already noted the need for `size - 1` for the outer loop; the compiler feedback made that unnecessarily hard to see.

### Other notes

- **Godbolt / Compiler Explorer:** not used; if a maintainer wants a shareable link, the snippet above should paste cleanly.
- **Insight:** The stack passes through `std/collections/_index_normalization.mojo` and `debug_assert`, which suggests a failed bounds check during const evaluation, but the final user-visible error obscures that. Improving the “assert failed at comptime” path to report the array type, length, and index would likely help a lot.
