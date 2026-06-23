# GPU `ParallelFor` mishandles empty or inverted boxes: zero grid launch and signed/unsigned guard

**Severity: Low** (requires an empty/invalid box; normal MFIter tiles are never empty)

## Explanation

`ParallelFor(ctx, stream, body, tile_box)` (`mojo/amrex/space3d/parallelfor.mojo:105`)
computes:

```mojo
var grid_size = ceildiv(box_cell_count(tile_box), KERNEL_BLOCK_SIZE)
```

For an empty box (e.g. an intersection result, or an inverted box where
`big_end < small_end`), `box_cell_count` returns 0 or a negative number:

1. `grid_size <= 0` is passed as `grid_dim` to `stream.enqueue_function`. CUDA and
   HIP reject grid dimension 0, so the caller gets an opaque launch error instead
   of the natural no-op.
2. In `_parallel_for_kernel` (`parallelfor.mojo:85`), the guard
   `if tid < active_cells` compares the unsigned `global_idx.x` against an `Int`.
   If a negative `active_cells` ever reaches a launched kernel, the signed value
   converts to a huge unsigned number, the guard passes for every thread, and the
   decomposition arithmetic (`linear_index % cells_per_plane` with negative
   `cells_per_plane`) hands out-of-box indices to `body` — an out-of-bounds write
   through whatever views the closure captured.

The CPU path (`for_each_box_cell`) handles empty boxes naturally because the
`range` loops simply don't execute.

## Proposed patch

Early-return before launching, in the GPU `ParallelFor` overload:

```mojo
var active_cells = box_cell_count(tile_box)
if active_cells <= 0:
    return
var grid_size = ceildiv(active_cells, KERNEL_BLOCK_SIZE)
```

In `_parallel_for_kernel`, make the guard explicitly signed so a bad count can
never widen to unsigned:

```mojo
if Int(tid) < active_cells:
```
