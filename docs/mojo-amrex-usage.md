# Mojo AMReX Usage Notes

Last updated: 2026-03-10

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

- `MultiFab.for_each_tile` yields a temporary `TileF64View` borrow for each tile.
- `MultiFab.array(mfi)` and `MultiFab.tile(mfi)` borrow through both the owning
  `MultiFab` and the current `MFIter` position.
- `Array4F64View` and `TileF64View` are non-owning views. Do not store them past
  the lifetime of the owning `MultiFab`, and do not let them escape the tile or
  iterator scope that produced them.
- `MFIter` methods that expose tile metadata require the iterator to be
  positioned on a valid tile. Once iteration is exhausted, metadata accessors
  raise instead of returning stale state.

## GPU Allocation Rules

- `AmrexRuntime.gpu_backend()` and `AmrexRuntime.gpu_enabled()` report the
  active AMReX backend only. `CUDA` and `HIP` are the supported device backends
  for AMReX in this repo.
- When the AMReX backend is `CUDA` or `HIP`, default `MultiFab` allocations are
  device-backed. Host-side `Array4` access is intentionally rejected in that
  case.
- Use `MultiFab(..., host_only=True)` when you explicitly need host-resident
  storage, for example to write initial conditions through `Array4` on the CPU
  before copying or communicating with other `MultiFab`s.
- `MultiFab.memory_info()` exposes whether a given allocation is host
  accessible, device accessible, managed, device-only, or pinned.
- On Apple Silicon, the AMReX backend remains CPU/host-only, but the resulting
  host-accessible `Array4` views can still be used by Mojo device kernels via
  shared physical memory. That is a Mojo-side execution path, not an AMReX GPU
  backend.

## Error Reporting

- The C ABI reports failures through status codes plus the thread-local
  `amrex_mojo_last_error_message()`.
- Mojo wrappers surface those failures as `Error` exceptions with the reported
  message.
- Loader failures include the concrete library path that was attempted and point
  users to either `pixi run install-amrex` or `AMREX_MOJO_LIBRARY_PATH=...`.
