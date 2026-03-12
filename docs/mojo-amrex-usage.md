# Mojo AMReX Usage Notes

Last updated: 2026-03-11

## Ownership Model

- `AmrexRuntime` is the root owner for AMReX process state and the loaded C API
  library.
- Owning wrappers such as `BoxArray`, `DistributionMapping`, `Geometry`,
  `MultiFab`, `MFIter`, and `ParmParse` retain a runtime lease so AMReX
  finalization cannot outlive those values.
- Owner wrappers are intentionally move-only for the MVP. There are no explicit
  clone APIs yet because the current binding surface does not need shared
  ownership of AMReX objects.

If an owner wrapper is used after it has been moved from, the wrapper now raises
an error before entering the C ABI instead of relying on a downstream null-handle
failure.

## Borrowing Rules

- `MultiFab.for_each_tile` yields a temporary `TileF64View` borrow for each
  tile, and `MultiFabF32.for_each_tile` yields `TileF32View`.
- `MultiFab.array(mfi)`, `MultiFab.tile(mfi)`, `MultiFabF32.array(mfi)`, and
  `MultiFabF32.tile(mfi)` borrow through both the owning multifab and the
  current `MFIter` position.
- `Array4F64View`, `TileF64View`, `Array4F32View`, and `TileF32View` are
  non-owning views. Do not store them past the lifetime of the owning multifab,
  and do not let them escape the tile or iterator scope that produced them.
- `MFIter` methods that expose tile metadata require the iterator to be
  positioned on a valid tile. Once iteration is exhausted, metadata accessors
  raise instead of returning stale state.

## GPU Allocation Rules

- AMReX GPU backends are intentionally disabled in this repo. `MultiFab`
  storage is always host-resident from the AMReX side.
- `MultiFab(..., host_only=True)` is still accepted for compatibility, but it
  is currently equivalent to the default allocation path.
- `MultiFab.memory_info()` exposes whether a given allocation is host
  accessible, device accessible, managed, device-only, or pinned.
- Mojo device kernels in user code are still supported. Use the staged view
  helpers with `std.gpu.host.DeviceContext`, as in the Mojo GPU smoke example.
  That is a Mojo-side execution path, not an AMReX GPU runtime.

## DevicePassable View Notes

- `Array4F64View`, `Array4F32View`, `TileF64View`, `TileF32View`, `Box3D`, and
  `IntVect3D` implement Mojo `DevicePassable` so they can be passed to device
  kernels.
- The device-side view types intentionally erase pointer provenance to
  `MutAnyOrigin`. Keeping the original owner origin in `device_type` causes the
  current Mojo compiler to reject `_to_device_type(...)` during alias/provenance
  checking.
- Direct use of native AMReX `Array4`/tile views as if they were already wired
  to an AMReX GPU runtime is not supported. The current workaround is to stage
  through a `DeviceBuffer` and then pass a rebuilt
  `Array4F32View[MutAnyOrigin]` to the kernel.
- The proposed long-term direct path is documented in
  `docs/mojo-amrex-direct-gpu-interop.md`.

## Error Reporting

- The C ABI reports failures through status codes plus the thread-local
  `amrex_mojo_last_error_message()`.
- Mojo wrappers surface those failures as `Error` exceptions with the reported
  message.
- Loader failures include the concrete library path that was attempted and point
  users to `pixi run build-capi`, `pixi run install-amrex`, or
  `AMREX_MOJO_LIBRARY_PATH=...`.
