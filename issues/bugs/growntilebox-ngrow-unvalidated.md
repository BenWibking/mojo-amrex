# `MFIter.growntilebox(ngrow)` accepts ghost widths larger than the MultiFab's, producing boxes that index past allocated fab data

**Severity: Medium** (out-of-bounds access reachable from safe API; requires caller to pass an oversized `ngrow`)

## Explanation

`MFIter._growntilebox_impl` (`mojo/amrex/space3d/mfiter.mojo:288`) and the C
equivalent `grown_tile_box` (`src/capi/mfiter.cpp:46`) grow the tile box by the
caller-supplied `ngrow` on every face that touches the valid box, with no upper
bound. The `MFIter` already stores the multifab's actual ghost width in
`default_ngrow`, but the explicit-`ngrow` overloads never compare against it.

Upstream AMReX `MFIter::growntilebox(ng)` has the same unclamped arithmetic, but
in C++ that is an explicitly unsafe API. Here the resulting `Box3D` is the
standard input to `Array4View` indexing, `TileView.fill`, and
`mfi.parallel_for(...)`, none of which bounds-check, so:

```mojo
var mf = MultiFab[AmrexFloat64](runtime, ba, dm, 1, intvect3d(1, 1, 1))
var mfi = mf.mfiter()
for _ in mfi:
    var box = mfi.growntilebox(intvect3d(4, 4, 4))  # > nGrow == 1
    mf.array(mfi).fill(box, 0.0)                    # writes outside the fab
```

silently corrupts adjacent heap memory.

Negative `ngrow` values are likewise unvalidated and can produce inverted boxes
(`small_end > big_end`), which `box_cell_count` turns into a negative cell count
(see `gpu-parallelfor-empty-box.md`).

## Proposed patch

Clamp-or-raise in `_growntilebox_impl` using the ghost width the iterator already
carries (`mojo/amrex/space3d/mfiter.mojo`):

```mojo
def _growntilebox_impl(ref self, ngrow: IntVect3D) raises -> Box3D:
    self._require_valid()
    if (
        Int(ngrow.x) > Int(self.default_ngrow.x)
        or Int(ngrow.y) > Int(self.default_ngrow.y)
        or Int(ngrow.z) > Int(self.default_ngrow.z)
    ):
        raise Error("growntilebox ngrow exceeds the MultiFab ghost width.")
    ...
```

Apply the same check in `amrex_mojo_mfiter_growntile_box_metadata`
(`src/capi/mfiter.cpp:271`) against the `ngrow` stored on `amrex_mojo_mfiter` at
creation, so direct C API consumers get the same protection.
