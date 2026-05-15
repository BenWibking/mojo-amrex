# GPU Synchronization Audit

This note records a static audit of GPU synchronization risks in the Mojo/AMReX
binding layer. The main concern is composition between Mojo-launched device work
and AMReX calls that may enqueue or consume device operations on AMReX-managed
streams.

## Findings

### 1. MFIter stream handle can follow stale global AMReX stream state

Status: fixed in `mojo/amrex/space3d/mfiter.mojo`.

`MFIter.stream()` returned a `DeviceStream` by reading the current
`amrex::Gpu::gpuStream()` through the C ABI. AMReX stream selection is global,
so another iterator or a direct `runtime.gpu_set_stream_index(...)` call could
change the active stream between `mfi.next()` and `mfi.stream(ctx)`. In that
case, a tile kernel could be enqueued onto the wrong AMReX stream.

The fix makes `MFIter.stream_handle()` and `MFIter.stream()` mutating accessors
and calls `_activate_current_stream()` immediately before reading
`gpu_stream()`.

### 2. MFIter does not pre-fence before entering multi-stream tile iteration

Status: open.

AMReX's native `MFIter` synchronizes the current stream before switching into
round-robin stream assignment when more than one stream and more than one
box/tile are active. The Mojo `MFIter` wrapper assigns tile streams directly in
`__init__`, `next()`, and `stream_handle()` without an equivalent pre-fence.

That is safe only if all earlier work that produces data for the tile loop has
already completed or if that work is on the same per-tile stream. It is risky
after direct interop code uses `AmrexRuntime.gpu_stream_handle(ctx)` or AMReX
work leaves operations queued on the current AMReX stream and the next tile loop
then starts launching on stream 1, stream 2, and so on. Those later stream
kernels have no dependency on the previous current-stream work.

Example of sensitive composition:

```mojo
var stream = ctx.create_external_stream(runtime.gpu_stream_handle(ctx))
stream.enqueue_function(produce_data, ...)

var mfi = mf.gpu_mfiter()
while mfi.is_valid():
    mfi.parallel_for(consume_data, mfi.tilebox())  # later tiles may use other streams
    mfi.next()
```

Recommended follow-up options:

- Mirror AMReX `MFIter` and synchronize the active stream before the first
  multi-stream tile launch when more than one stream/tile is active.
- Prefer a narrower dependency mechanism if Mojo exposes stream events that can
  make every AMReX tile stream wait on the prior producing stream.
- Add a regression test that queues a producer kernel through
  `gpu_stream_handle(ctx)`, then immediately starts a multi-tile
  `gpu_mfiter()` consumer loop.

### 3. `MFIter.synchronize()` can suppress later final synchronization

Status: open.

`MFIter.synchronize()` calls `_finalize()`. `_finalize()` fences the AMReX stream
set and then sets `finalized = True`. The iterator can still be valid after this
call. If a caller synchronizes in the middle of iteration, resumes launching
kernels, and then exhausts or destroys the iterator, the later finalization path
sees `finalized == True` and skips the stream fence for the kernels launched
after the manual synchronization.

Example of sensitive composition:

```mojo
var mfi = mf.gpu_mfiter()
mfi.parallel_for(first_kernel, mfi.tilebox())
mfi.synchronize()

mfi.next()
mfi.parallel_for(second_kernel, mfi.tilebox())
mfi.next()  # reaching invalid state no longer fences second_kernel

mf.sum(0)  # may observe stale data from second_kernel
```

Recommended follow-up options:

- Split "synchronize all streams now" from "mark this iterator finalized".
- Track whether any kernel has been launched since the last synchronization and
  only skip `_finalize()` when no dirty stream work remains.
- Consider making `synchronize()` either consume the iterator or leave it
  explicitly reusable with a reset dirty/finalized state.
- Add a regression test that calls `synchronize()` mid-iteration, launches
  another tile kernel, then immediately calls a reduction or `fill_boundary`.

### 4. AMReX wrapper calls can consume Mojo tile kernels before the iterator is finalized

Status: open.

`MFIter._finalize()` fences all AMReX streams when iteration reaches the invalid
state or when `mfi.synchronize()` is called. However, `MultiFab` operations such
as `set_val`, `plus`, `mult`, `copy_from`, `parallel_copy_from`,
`fill_boundary`, reductions, and plotfile output immediately call into AMReX.
If a caller launches Mojo kernels through an `MFIter` and then calls one of
those `MultiFab` operations before exhausting or synchronizing the iterator,
AMReX may consume stale data. This is a binding-level lifetime/order issue:
the `MultiFab` wrapper has no visibility into outstanding tile kernels borrowed
through a separate `MFIter`.

Examples of sensitive composition:

```mojo
var mfi = mf.gpu_mfiter()
while mfi.is_valid():
    mfi.parallel_for(update_cell, mfi.tilebox())
    break

mf.fill_boundary(geometry)  # may run before update_cell completes
```

```mojo
var mfi = mf.gpu_mfiter()
var stream = mfi.stream(ctx)
stream.enqueue_function(kernel, ...)

var total = mf.sum(0)  # may observe pre-kernel data unless mfi is synchronized
```

Recommended follow-up options:

- Document a hard rule: complete iteration or call `mfi.synchronize()` before
  any AMReX call that reads or writes affected `MultiFab` data.
- Add an explicit synchronization guard/token for GPU tile borrows so
  `MultiFab` operations can fence or reject active unsynchronized GPU work.
- Add tests that intentionally compose Mojo kernels with `fill_boundary`,
  `parallel_copy_from`, `set_val`, `plus`, `mult`, reductions, and plotfile
  output before and after explicit iterator synchronization.

### 5. Runtime-level stream handle has an implicit dependency on AMReX global state

Status: open.

`AmrexRuntime.gpu_stream_handle(ctx)` returns the current AMReX stream handle.
This is useful for low-level interop, but it has no stream-index argument and no
scope tying it to a tile or operation. Callers must know whether previous AMReX,
Mojo, or iterator operations changed the active stream selection. This API also
does not provide a way to express dependencies from the returned current stream
onto the full AMReX stream set used by `MFIter`.

Recommended follow-up options:

- Prefer tile-scoped APIs such as `MFIter.stream(ctx)` for normal user code.
- Consider adding a stream-indexed accessor that sets the AMReX stream before
  returning the handle.
- Consider an all-stream synchronization or event broadcast helper for code that
  intentionally transitions from current-stream interop to multi-stream
  `MFIter` work.
- Keep `gpu_stream_handle(ctx)` documented as a low-level API that reflects
  mutable global AMReX stream state.

### 6. Staged host/device helpers enqueue asynchronous copies without an ordering hook

Status: open.

`StagedArray4F32.load_from_host(...)` and
`StagedArray4F32.store_to_host(...)` enqueue copies through `DeviceContext`.
Callers may enqueue kernels through a separate `DeviceStream`, but the helper
does not expose a stream or event dependency. That makes it easy to write code
where host-to-device copy, kernel execution, and device-to-host copy are not
explicitly ordered.

Recommended follow-up options:

- Accept a `DeviceStream` for staged copies if the Mojo API supports stream
  copies.
- Provide explicit synchronization methods or examples showing the required
  ordering.
- Add a focused staged-copy smoke test once the local Mojo GPU target issue is
  resolved.

## Validation Notes

After fixing finding 1:

- `pixi run format-mojo` passed.
- `pixi run test` rebuilt the C ABI, passed CAPI tests, and passed
  `runtime_geometry_test`.
- `pixi run test` then failed in `multifab_functional_test.mojo` because the
  local Mojo toolchain reported `Unknown GPU architecture detected` while
  instantiating `DeviceContext`. That appears to be an environment/compiler
  limitation rather than a failure caused by the stream-handle fix.
