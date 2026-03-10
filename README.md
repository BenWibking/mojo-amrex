# mojo-amrex

Mojo bindings to AMReX, implemented as a narrow C ABI plus RAII-style Mojo objects.

The current repo contains:

- a design note in `docs/mojo-amrex-bindings-plan.md`
- a real AMReX-backed C ABI under `src/capi`
- a Mojo package under `mojo/amrex`
- automated C++ and Mojo tests under `tests/`
- an install path that exposes `amrex` as a top-level Mojo package in the active environment
- a working MultiFab smoke example in `examples/multifab_smoke.mojo`
- an Apple Silicon GPU variant of the smoke example in `examples/multifab_smoke_apple_gpu.mojo`
- an MPI ghost-exchange example in `examples/multifab_mpi_exchange.mojo`

The current MVP covers:

1. runtime initialization and shutdown
2. `BoxArray`, `DistributionMapping`, `Geometry`, and `MultiFab`
3. tile metadata plus zero-copy `Array4` pointer access for host-accessible storage
4. reductions for `MultiFab`
5. a Mojo example that allocates a `MultiFab`, fills all tiles, and validates the sum

## Quickstart

From the repo root:

```bash
curl -fsSL https://pixi.sh/install.sh | sh
pixi run bootstrap
pixi shell
mojo examples/multifab_smoke.mojo
```

If you just installed `pixi`, restart your shell first so `pixi` is on `PATH`.
`bootstrap` configures the build, compiles the AMReX C ABI, and installs both
the shared library and `amrex.mojopkg` into the default pixi environment. A
fresh checkout does not need a preexisting AMReX clone; CMake fetches AMReX
from GitHub during the initial configure step. The default pixi build now
enables MPI, so both examples under `examples/` can use the installed library
without a separate MPI-only build tree.

## Layout

```text
.
|-- CMakeLists.txt
|-- docs/
|-- examples/
|-- mojo/
|   `-- amrex/
|       |-- __init__.mojo
|       |-- ffi.mojo
|       |-- loader.mojo
|       `-- space3d/
|-- src/
|   `-- capi/
|-- tests/
`-- pixi.toml
```

## Commands

With `pixi`:

```bash
pixi run bootstrap
pixi run configure
pixi run configure-mpi
pixi run build-capi
pixi run build-capi-mpi
pixi run build-tests
pixi run build-tests-mpi
pixi run install-amrex
pixi run install-mojo-package
pixi run package-mojo
pixi run build-multifab-smoke
pixi run run-multifab-smoke
pixi run run-multifab-smoke-script
pixi run build-multifab-smoke-apple-gpu
pixi run run-multifab-smoke-apple-gpu
pixi run run-multifab-smoke-apple-gpu-script
pixi run run-multifab-mpi-exchange
pixi run test-capi
pixi run test-capi-mpi
pixi run test-mojo-runtime
pixi run test-mojo-runtime-mpi
pixi run test-mojo-multifab
pixi run test-mojo-multifab-mpi
pixi run test
pixi run test-mpi
pixi run format-mojo
```

Notes:

- `pixi run bootstrap` is the one-shot setup path for a fresh checkout. It
  runs `configure`, `build-capi`, and `install-amrex`.
- By default the CMake build fetches AMReX from
  `https://github.com/AMReX-Codes/amrex/releases/download/26.03/amrex-26.03.tar.gz`
  and verifies the pinned SHA-256 before configuring a 3D, double-precision
  MPI-enabled build suitable for the MVP bindings. The default backend is
  `AMREX_MOJO_GPU_BACKEND=NONE`.
- `pixi run configure` now uses the pixi-provided OpenMPI wrapper compilers so
  the default `build/` tree and installed C ABI are MPI-capable.
- `pixi run configure-mpi`, `build-capi-mpi`, and `build-tests-mpi` remain as
  explicit MPI task aliases, but they target the same default `build/` tree.
- To enable an AMReX GPU backend, configure with
  `-DAMREX_MOJO_GPU_BACKEND=CUDA` or `-DAMREX_MOJO_GPU_BACKEND=HIP`.
- When `AMREX_MOJO_GPU_BACKEND` is `CUDA` or `HIP`, default `MultiFab`
  allocations are device-backed through `The_Async_Arena()`. Use
  `MultiFab(..., host_only=True)` from Mojo, or
  `AMREX_MOJO_MULTIFAB_MEMORY_HOST_ONLY` through the C ABI, when you need a
  host-resident `MultiFab` for direct `Array4` writes.
- On Apple Silicon, the AMReX backend still runs as `NONE`/host-only, but
  `Array4` views remain usable for Mojo device kernels via shared physical
  memory. That path is separate from AMReX's CUDA/HIP backend support.
- `pixi run run-multifab-smoke-apple-gpu` keeps the smoke-example control flow
  and output behavior, but stages each tile through
  `std.gpu.host.DeviceContext` and runs the tile update on Metal. The staging
  buffers use `Float32` because Apple GPU kernels do not expose `Float64`
  arithmetic.
- To build against a local AMReX checkout instead, configure with
  `-DAMREX_MOJO_AMREX_SOURCE_DIR=/path/to/amrex`.
- `pixi run install-amrex` installs the C API library into the active env's
  `lib/` directory and installs `amrex.mojopkg` into the env's `lib/mojo/`
  directory, so bare commands like `mojo examples/multifab_smoke.mojo` work
  from the repo root inside `pixi shell` without `-I mojo`. After `bootstrap`,
  `mpiexec -n 2 mojo examples/multifab_mpi_exchange.mojo` also uses that same
  installed library by default.
- `pixi run test` runs the C++ ABI test through `ctest` and the Mojo
  functional tests against the local build tree. The Mojo test tasks rebuild
  and install `amrex.mojopkg` into the active pixi env before running, then set
  `AMREX_MOJO_LIBRARY_PATH=./build/src/capi/libamrex_mojo_capi_3d.dylib`.
- `pixi run run-multifab-mpi-exchange` packages the current Mojo bindings,
  points them at the default `build/` tree, and runs the MPI example with
  `mpiexec -n 2`.
- `pixi run test-mpi` runs the two-rank MPI variants of the C++ and Mojo tests
  from the default MPI-enabled `build/` tree.
- The public Mojo surface now uses move-only wrapper objects such as
  `AmrexRuntime`, `BoxArray`, `Geometry`, and `MultiFab`. The raw handle-level
  bindings remain available under `amrex.ffi`.

## Testing

The automated test suite currently has three pieces:

- `tests/capi/runtime_multifab_test.cpp` exercises the exported C ABI directly
  through runtime, geometry, `MultiFab`, `MFIter`, `ParmParse`, plotfile, and
  null-handle diagnostic paths.
- `tests/mojo/runtime_geometry_test.mojo` covers runtime queries plus core
  domain and geometry objects from Mojo.
- `tests/mojo/multifab_functional_test.mojo` covers `for_each_tile`, `MFIter`,
  borrowed `Array4` access, arithmetic, reductions, `ParmParse`, and plotfile
  output from Mojo, including `fill_boundary` and `parallel_copy_from`. The
  direct `Array4` tests use explicit `host_only=True` allocations so the same
  suite can run when the AMReX backend defaults to device-backed `MultiFab`
  storage.

Run `pixi run test` after changes to the bindings layer.
Run `pixi run test-mpi` to exercise the MPI-enabled build on 2 ranks.

## Ownership

The binding model is intentionally strict about ownership:

- `AmrexRuntime` is the root owner. `BoxArray`, `Geometry`, `MultiFab`, and
  other owning wrappers retain a runtime lease so AMReX finalization cannot
  race object destruction.
- Owner wrappers remain move-only for the MVP. There are no explicit clone APIs
  until a concrete workflow demonstrates that shared owner semantics are needed.
- `MultiFab.for_each_tile` and `MultiFab.array(mfi)` expose borrowed tile views.
  Treat those `TileF64View` and `Array4F64View` values as non-escaping borrows;
  they are only valid while the owning `MultiFab` and iterator state remain
  live.
- When CUDA/HIP support is enabled, default `MultiFab` storage is device-backed.
  Host-side `Array4` access then requires an explicit `host_only=True`
  allocation; otherwise the wrapper raises instead of handing out an invalid
  host pointer.
- If library discovery fails, the loader now reports the concrete path it tried
  and suggests either `pixi run install-amrex` or
  `AMREX_MOJO_LIBRARY_PATH=/path/to/libamrex_mojo_capi_3d.dylib`.

Focused usage notes for ownership, borrowing, and diagnostics live in
`docs/mojo-amrex-usage.md`.

## License

This repository is licensed under the BSD 3-Clause License. See `LICENSE`
for the full text.
