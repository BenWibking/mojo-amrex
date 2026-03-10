# mojo-amrex

Mojo bindings to AMReX, implemented as a narrow C ABI plus RAII-style Mojo objects.

The current repo contains:

- a design note in `docs/mojo-amrex-bindings-plan.md`
- a real AMReX-backed C ABI under `src/capi`
- a Mojo package under `mojo/amrex`
- automated C++ and Mojo tests under `tests/`
- an install path that exposes `amrex` as a top-level Mojo package in the active environment
- a working MultiFab smoke example in `examples/multifab_smoke.mojo`
- an MPI ghost-exchange example in `examples/multifab_mpi_exchange.mojo`

The current MVP covers:

1. runtime initialization and shutdown
2. `BoxArray`, `DistributionMapping`, `Geometry`, and `MultiFab`
3. tile metadata plus zero-copy `Array4` pointer access on CPU
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
from GitHub during the initial configure step.

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
  and verifies the pinned SHA-256 before configuring a 3D, CPU-only,
  double-precision build suitable for the MVP bindings.
- `pixi run configure-mpi` creates a separate `build-mpi/` tree with
  `AMREX_MOJO_ENABLE_MPI=ON` and uses the pixi-provided OpenMPI wrapper
  compilers.
- To build against a local AMReX checkout instead, configure with
  `-DAMREX_MOJO_AMREX_SOURCE_DIR=/path/to/amrex`.
- `pixi run install-amrex` installs the C API library into the active env's
  `lib/` directory and installs `amrex.mojopkg` into the env's `lib/mojo/`
  directory, so bare commands like `mojo examples/multifab_smoke.mojo` work
  from the repo root inside `pixi shell` without `-I mojo`.
- `pixi run test` runs the C++ ABI test through `ctest` and the Mojo
  functional tests against the local build tree. The Mojo test tasks rebuild
  and install `amrex.mojopkg` into the active pixi env before running, then set
  `AMREX_MOJO_LIBRARY_PATH=./build/src/capi/libamrex_mojo_capi_3d.dylib`.
- `pixi run run-multifab-mpi-exchange` packages the current Mojo bindings,
  points them at `build-mpi/`, and runs the MPI example with `mpiexec -n 2`.
- `pixi run test-mpi` runs the two-rank MPI variants of the C++ and Mojo tests
  from the separate `build-mpi/` tree.
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
  output from Mojo, including `fill_boundary` and `parallel_copy_from`.

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
- If library discovery fails, the loader now reports the concrete path it tried
  and suggests either `pixi run install-amrex` or
  `AMREX_MOJO_LIBRARY_PATH=/path/to/libamrex_mojo_capi_3d.dylib`.

Focused usage notes for ownership, borrowing, and diagnostics live in
`docs/mojo-amrex-usage.md`.

## License

This repository is licensed under the BSD 3-Clause License. See `LICENSE`
for the full text.
