# On GPU builds, `MultiFab.tile()`/`array()` return device-pointer views that crash when accessed from host code

**Severity: Medium-Low** (host segfault on GPU builds via an API that looks host-safe; no data corruption)

## Explanation

`MultiFab._array_for_mfiter` (`mojo/amrex/space3d/multifab.mojo:245`) chooses the
data pointer based solely on whether the loaded AMReX library has a GPU backend:

```mojo
if self._use_device_array():
    return device_array4_view_from_mfiter_as_origin[...](...)
return array4_view_from_mfiter[...](...)
```

so on a CUDA/HIP build, `MultiFab.tile(mfi)` and `MultiFab.array(mfi)` always
wrap the *device* pointer (the C side `require_device_accessible` passes because
the data lives in the device arena). But `TileView` and `Array4View` expose plain
host-side accessors — `fill`, `__getitem__`, `__setitem__` — with nothing
distinguishing them from the CPU case. Host code that works on a CPU build
segfaults on a GPU build with non-managed memory:

- `examples/Multifab/multifab.mojo:17,50` — `fill_tile(source.tile(source_mfi))`
  runs `TileView.fill`'s host loop over the device pointer.
- `examples/Multifab/multifab_mpi.mojo:79,98` — `multifab.array(mfi)` is read
  cell-by-cell on the host (`has_nonzero_ghost_cells`, `interface_ghost_sample`).
- `examples/HeatEquation/heat_equation_vis.mojo:124` — `slice_array` reads
  `phi_src[i, j, mid_plane]` on the host to build a NumPy array.

The dedicated escape hatch is already named honestly (`unsafe_device_array`), but
the default `array()`/`tile()` silently become equally unsafe on GPU builds.

## Proposed patch

Make the host paths explicit and checked:

1. In `_array_for_mfiter`, only return the device pointer when the storage is not
   host accessible AND the caller asked for it; otherwise return the host pointer
   (managed/pinned arenas are host accessible, so CPU-style code keeps working):

```mojo
def _array_for_mfiter[...](...) raises -> Array4View[Self.T, owner_origin]:
    if self._use_device_array():
        if not self.memory_info().host_accessible:
            raise Error(
                "MultiFab storage is device-only; use unsafe_device_array() "
                "and a GPU kernel, or create the MultiFab with host-accessible memory."
            )
    return array4_view_from_mfiter[...](...)
```

2. Keep kernel launches on the device view by having `MFIter.parallel_for` /
   `ParallelFor` obtain it via `unsafe_device_array` (as the GPU path of the
   examples effectively expects), rather than overloading the meaning of
   `array()`.
