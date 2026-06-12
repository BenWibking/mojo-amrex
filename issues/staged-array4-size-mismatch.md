# `StagedArray4.load_from_host`/`store_to_host` accept any host view without checking it matches the staged buffer's size

**Severity: Low** (out-of-bounds copy only if the caller passes a different view than the one used at construction)

## Explanation

`StagedArray4` (`mojo/amrex/space3d/gpu.mojo:19`) sizes its device buffer from
the view supplied to `__init__`, but the transfer methods take an independent
`array` parameter and copy `len(buffer)` elements blindly:

```mojo
def load_from_host[...](mut self, ref ctx: DeviceContext, array: Array4View[Self.T, origin],) raises:
    ctx.enqueue_copy[Self.dtype](self.buffer, array.data)

def store_to_host[...](mut self, ref ctx: DeviceContext, array: Array4View[Self.T, origin],) raises:
    ctx.enqueue_copy[Self.dtype](array.data, self.buffer)
```

Nothing ties `array` to the view the stage was built from. Passing a view of a
smaller fab (or any other tile) reads or writes past the end of the host
allocation by the difference in `storage_size()`. The same applies to
`StagedTile.store_to_host(ctx, tile)` with a different tile than the constructor's.
Since the type and origin parameters match across tiles of the same multifab,
the compiler cannot catch this.

## Proposed patch

Validate the layout before each copy:

```mojo
def load_from_host[...](mut self, ref ctx: DeviceContext, array: Array4View[Self.T, origin],) raises:
    if array.storage_size() != self.device_view_.storage_size():
        raise Error("StagedArray4 transfer requires a view matching the staged layout.")
    ctx.enqueue_copy[Self.dtype](self.buffer, array.data)
```

(Comparing the full `Array4LayoutMetadata` fields would be stricter and also
catches same-size/different-shape mismatches; storage size alone prevents the
memory-safety problem.)
