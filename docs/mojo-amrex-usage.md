# Mojo AMReX Usage Notes

Last updated: 2026-03-25

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

- The default `pixi run bootstrap` / `pixi run configure` path now sets
  `AMREX_MOJO_GPU_BACKEND=AUTO`, which probes for a CUDA compiler first, then a
  HIP compiler, and falls back to `NONE` if neither toolchain is available.
- CUDA/HIP AMReX builds are now supported as an opt-in path. In those builds,
  `MultiFab.memory_info()` tells you whether a given allocation is host
  accessible, device accessible, managed, device-only, or pinned.
- `MultiFab(..., host_only=True)` still forces host-accessible storage. Use the
  default allocation path when you want AMReX to choose its normal GPU-capable
  arena in a CUDA/HIP build.
- Mojo device kernels in user code are still supported. Use the staged helper
  types in `amrex.space3d.gpu` (`StagedArray4F32` / `StagedTileF32`) with
  `std.gpu.host.DeviceContext` when you want the portable host-to-device
  staging path. That is a Mojo-side execution path, not an AMReX GPU runtime.

## Direct GPU Interop Rules

- The direct path currently supports CUDA and HIP only.
- `AmrexRuntime.gpu_stream_handle(ctx)` returns the current AMReX GPU stream
  handle as a raw pointer-sized value through the C ABI after checking that
  `ctx` matches the AMReX backend and device.
- Wrap that handle with
  `ctx.create_external_stream(runtime.gpu_stream_handle(ctx))` and enqueue Mojo
  kernels on the returned `DeviceStream`.
- Compile kernels first with `ctx.compile_function(...)`; the wrapped
  `DeviceStream` does not provide the `ctx.enqueue_function[...]` convenience
  form.
- Borrow AMReX device storage with `MultiFab.unsafe_device_array(...)` or
  `MultiFabF32.unsafe_device_array(...)`. Those methods are intentionally named
  `unsafe` because they return raw device pointer metadata.
- Do not use host indexing, `__getitem__`, `__setitem__`, `.fill()`, or any
  other host-side accessors on values returned by `unsafe_device_array(...)`.
  Today they reuse the same `Array4*View` structs as the host path, so the type
  does not stop you from doing the wrong thing.
- Refresh the wrapped `DeviceStream` after AMReX operations that may change the
  current stream selection if you need to keep following AMReX's active stream.
- Synchronize the wrapped `DeviceStream` before host-visible uses such as
  plotfile output or cleanup that depends on completed kernel work.

## DevicePassable View Notes

- `Array4F64View`, `Array4F32View`, `TileF64View`, `TileF32View`, `Box3D`, and
  `IntVect3D` implement Mojo `DevicePassable` so they can be passed to device
  kernels.
- The device-side view types intentionally erase pointer provenance to
  `MutAnyOrigin`. Keeping the original owner origin in `device_type` causes the
  current Mojo compiler to reject `_to_device_type(...)` during alias/provenance
  checking.
- Direct AMReX GPU interop is now available for CUDA/HIP builds through
  `gpu_stream_handle(ctx)` plus `unsafe_device_array(...)`.
- The staged `DeviceBuffer` workaround remains the portable fallback for CPU
  builds, Metal, and any configuration where direct AMReX GPU interop is not
  available.
- Detailed design notes and remaining caveats live in
  `docs/mojo-amrex-direct-gpu-interop.md`.

## Error Reporting

- The C ABI reports failures through status codes plus the thread-local
  `amrex_mojo_last_error_message()`.
- Mojo wrappers surface those failures as `Error` exceptions with the reported
  message.
- Loader failures include the concrete library path that was attempted and point
  users to `pixi run build-capi`, `pixi run install-amrex`, or
  `AMREX_MOJO_LIBRARY_PATH=...`.
