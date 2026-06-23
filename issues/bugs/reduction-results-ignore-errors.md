# `MultiFab.min/max/sum/norm0/norm1/norm2` silently return 0.0 for invalid component indices

**Severity: Medium** (silent wrong results; no crash)

## Explanation

The C reductions (`amrex_mojo_multifab_min` and friends,
`src/capi/multifab.cpp:1074-1150`) signal an invalid component by setting the
thread-local last-error and returning `0.0`. The Mojo FFI wrappers
(`mojo/amrex/ffi.mojo:840`, `869-886`) and the `MultiFab` methods
(`mojo/amrex/space3d/multifab.mojo:260-282`) return that `0.0` directly without
checking the error state, so:

```mojo
var mf = MultiFab[AmrexFloat64](runtime, ba, dm, 1)
print(mf.sum(3))  # prints 0.0 — no error, comp 3 does not exist
```

A typo'd component index produces a plausible-looking result instead of an
exception. `0.0` is also a perfectly valid reduction result, so the caller cannot
distinguish the error case at all.

## Proposed patch

Validate the component on the Mojo side before calling into C, in each of the six
`MultiFab` reduction methods (`mojo/amrex/space3d/multifab.mojo`):

```mojo
def min(ref self, comp: Int) raises -> Float64:
    var handle = self._handle()
    self._require_component(comp)
    return multifab_min(self.runtime[].lib, handle, comp)

def _require_component(ref self, comp: Int) raises:
    if comp < 0 or comp >= self.ncomp():
        raise Error("MultiFab component index is out of range.")
```

(Alternative: give the C API status-code variants that return the value through an
out-pointer, and have the Mojo wrappers call `raise_on_error`. The Mojo-side check
is the smaller change and matches the existing `_require_tile_index` pattern.)
