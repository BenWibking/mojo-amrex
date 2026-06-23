# `amrex_mojo_multifab_copy` does not validate BoxArray compatibility or `ngrow`, allowing out-of-bounds memory access from safe Mojo code

**Severity: High** (memory corruption reachable from the safe `MultiFab.copy_from` API)

## Explanation

`amrex_mojo_multifab_copy` (`src/capi/multifab.cpp:1261`) validates only the component
ranges before forwarding to `amrex::Copy`:

- It never checks that `dst` and `src` share the same `BoxArray` and
  `DistributionMapping`. `amrex::Copy` (`AMReX_FabArray.H:191`) iterates the
  destination's `MFIter` and indexes `src.const_array(mfi)` with the destination's
  boxes. In release builds there is no assertion, so mismatched layouts read (and
  convert/write) out of bounds.
- It never checks `ngrow` against either multifab's ghost width. `amrex::Copy`
  computes `mfi.growntilebox(nghost)` from the caller-supplied `nghost` without
  clamping, so `ngrow > nGrowVect()` walks past the allocated fab data on both the
  read and write side.

Both holes are reachable from the safe Mojo wrapper
`MultiFab.copy_from(source, src_comp, dst_comp, ncomp, ngrow)`
(`mojo/amrex/space3d/multifab.mojo:302`), which passes `ngrow` through unchecked
and accepts any second multifab of the same dtype. A user who builds two multifabs
from different BoxArrays, or passes `ngrow` larger than the ghost width used at
creation, gets silent heap corruption instead of an error.

`amrex_mojo_multifab_parallel_copy` handles the mismatched-layout case correctly
(AMReX `ParallelCopy` is designed for it), but it likewise forwards
`src_ngrow`/`dst_ngrow` without bounding them to the multifabs' ghost widths.

## Proposed patch

In `amrex_mojo_multifab_copy`, after the component-range validation:

```cpp
const auto compatible = visit_multifab_pair(
    dst_multifab,
    const_cast<amrex_mojo_multifab_t*>(src_multifab),
    [&](auto& dst_value, const auto& src_value) {
        return dst_value.boxArray() == src_value.boxArray()
            && dst_value.DistributionMap() == src_value.DistributionMap();
    });
if (!compatible) {
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_INVALID_ARGUMENT,
        "multifab_copy requires source and destination with matching BoxArray "
        "and DistributionMapping.");
}

const auto grow = amrex_mojo::detail::to_intvect(ngrow);
const auto ngrow_ok = visit_multifab_pair(
    dst_multifab,
    const_cast<amrex_mojo_multifab_t*>(src_multifab),
    [&](auto& dst_value, const auto& src_value) {
        return grow.allLE(dst_value.nGrowVect()) && grow.allLE(src_value.nGrowVect());
    });
if (!ngrow_ok) {
    return amrex_mojo::detail::set_last_error(
        AMREX_MOJO_STATUS_INVALID_ARGUMENT,
        "multifab_copy requires ngrow <= the ghost width of both multifabs.");
}
```

Apply the same `ngrow <= nGrowVect()` validation to `src_ngrow`/`dst_ngrow` in
`amrex_mojo_multifab_parallel_copy` (`src/capi/multifab.cpp:1346`). Negative
`ngrow` components should also be rejected.
