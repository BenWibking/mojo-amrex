# mojo-amrex Implementation Notes

Last updated: 2026-03-15

## Overview

`mojo-amrex` is split into three layers:

1. AMReX itself
2. a narrow `extern "C"` shim in `src/capi/`
3. user-facing Mojo wrappers in `mojo/amrex/`

The project uses a C ABI boundary because Mojo's FFI model is built around C
symbols, explicit handles, and POD data exchange. The C shim owns the C++
interaction with AMReX; the Mojo layer owns wrapper ergonomics and lifecycle
checks.

## Repository Structure

- `src/capi/`: exported C ABI and CMake targets
- `mojo/amrex/`: loader, raw FFI, runtime, and 3D wrapper surface
- `examples/`: runnable `Multifab` and `HeatEquation` examples for host, direct GPU interop, and MPI workflows
- `tests/capi/`: ABI-level regression tests
- `tests/mojo/`: wrapper-level regression tests

## Ownership Model

- `AmrexRuntime` is the root owner for AMReX process state and the loaded C ABI
  library.
- Owning wrappers such as `BoxArray`, `DistributionMapping`, `Geometry`,
  `MultiFab`, `MFIter`, and `ParmParse` retain a runtime lease so AMReX
  finalization cannot outlive them.
- Owner wrappers are move-only. Shared-owner APIs are intentionally absent
  until there is a concrete need for them.
- Borrowed views such as `Array4*View` and tile views are non-owning and are
  only valid while the source object and iterator state remain live.

More detailed usage rules live in `docs/mojo-amrex-usage.md`.

## Library Loading

The Mojo package loads the C ABI shared library at runtime. That keeps the
bootstrap path explicit and avoids requiring direct C++ binding support from
Mojo.

Typical install path:

- `pixi run build-capi` builds the shared library
- `pixi run install-amrex` installs the library, headers, and `amrex.mojopkg`

If library discovery fails, the loader reports the path it tried and suggests
rebuilding or setting `AMREX_MOJO_LIBRARY_PATH`.

## GPU Paths

There are two GPU-related workflows in this repository:

- staged Mojo GPU execution helpers in `mojo/amrex/space3d/gpu.mojo`, which
  copy host-backed tile data through Mojo buffers and remain the portable
  fallback
- direct CUDA/HIP interop, which shares a Mojo stream with AMReX and borrows
  device-accessible tile metadata from `MultiFab`

The direct path is intentionally narrow and documented in
`docs/mojo-amrex-direct-gpu-interop.md`.

## Further Background

The original architecture and scope planning document is
`docs/mojo-amrex-bindings-plan.md`. It remains useful background, but it is no
longer the best entry point for day-to-day use of the repository.
