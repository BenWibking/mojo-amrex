# mojo-amrex

Mojo bindings to AMReX, implemented as a narrow C ABI plus RAII-style Mojo objects.

The current repo contains:

- a design note in `docs/mojo-amrex-bindings-plan.md`
- a real AMReX-backed C ABI under `src/capi`
- a Mojo package under `mojo/amrex`
- automated C++ and Mojo tests under `tests/`
- an install path that exposes `amrex` as a top-level Mojo package in the active environment
- a working MultiFab smoke example in `examples/multifab_smoke.mojo`
- a Mojo GPU variant of the smoke example in `examples/multifab_smoke_mojo_gpu.mojo`
- an MPI ghost-exchange example in `examples/multifab_mpi_exchange.mojo`

The current MVP covers:

1. runtime initialization and shutdown
2. `BoxArray`, `DistributionMapping`, `Geometry`, and `MultiFab`
3. tile metadata plus zero-copy `Array4` pointer access for host-accessible storage
4. opt-in direct CUDA/HIP GPU interop by sharing a Mojo stream with AMReX
5. device-pointer borrows for GPU-backed `MultiFab` tiles
6. reductions for `MultiFab`
7. a Mojo example that allocates a `MultiFab`, fills all tiles, and validates the sum

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
pixi run build-multifab-smoke-mojo-gpu
pixi run run-multifab-smoke-mojo-gpu
pixi run run-multifab-smoke-mojo-gpu-script
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
  `https://github.com/WeiqunZhang/amrex.git` on the
  `external_gpu_stream` branch before configuring a 3D, double-precision
  MPI-enabled build suitable for the MVP bindings.
- `pixi run configure` now uses the pixi-provided OpenMPI wrapper compilers so
  the default `build/` tree and installed C ABI are MPI-capable.
- `pixi run configure-mpi`, `build-capi-mpi`, and `build-tests-mpi` remain as
  explicit MPI task aliases, but they target the same default `build/` tree.
- `pixi run bootstrap` and `pixi run configure` now default
  `AMREX_MOJO_GPU_BACKEND` to `AUTO`. Configure probes for CUDA first, then
  HIP, and falls back to `NONE` when neither toolchain is available.
- Direct AMReX GPU interop still requires a CUDA or HIP AMReX build. Override
  autodetection with `-DAMREX_MOJO_GPU_BACKEND=CUDA`,
  `-DAMREX_MOJO_GPU_BACKEND=HIP`, or `-DAMREX_MOJO_GPU_BACKEND=NONE` when you
  need a specific backend.
- `pixi run run-multifab-smoke-mojo-gpu` keeps the smoke-example control flow
  and output behavior, but runs the tile update through Mojo device kernels on
  any Mojo-supported accelerator backend. It stages host-backed `Array4` data
  through `DeviceBuffer`s before launch and uses `Float32` storage for broad
  backend compatibility. That is Mojo-kernel support in user code, not AMReX
  GPU-runtime interop.
- The direct AMReX GPU path works by exporting the current Mojo stream handle,
  installing it as AMReX's active external stream for a scope, and then
  borrowing device pointers from `MultiFab`. AMReX remains the owner of device
  memory and stream ordering; Mojo only provides the stream handle and kernels.
- The current wrapper surface for that path is
  `AmrexRuntime.external_gpu_stream_scope(ctx, sync_on_exit=...)` plus
  `MultiFab.unsafe_device_array(...)` / `MultiFabF32.unsafe_device_array(...)`.
- The current installed Mojo toolchain in this repo exposes raw CUDA/HIP stream
  export through the internal modules `std.gpu.host._nvidia_cuda` and
  `std.gpu.host._amdgpu_hip`. Those are unstable implementation details; when a
  stable stdlib export surface is available, the AMReX-side design does not
  need to change.
- To build against a local AMReX checkout instead, configure with
  `-DAMREX_MOJO_AMREX_SOURCE_DIR=/path/to/amrex`.
- `pixi run build-capi` now also refreshes the C API dylib in the active env's
  `lib/` directory after each successful build, so bare commands like
  `mojo examples/multifab_smoke.mojo` do not pick up a stale installed copy.
- `pixi run install-amrex` still installs `amrex.mojopkg` into the env's
  `lib/mojo/` directory and runs the full CMake install step for headers and
  other install artifacts.
- `pixi run test` runs the C++ ABI test through `ctest` and the Mojo
  functional tests against the current env-installed library. The Mojo test
  tasks rebuild the C API, install `amrex.mojopkg` into the active pixi env,
  and then run without an explicit `AMREX_MOJO_LIBRARY_PATH` override.
- `pixi run run-multifab-mpi-exchange` packages the current Mojo bindings,
  rebuilds the C API into the active env, and runs the MPI example with
  `mpiexec -n 2`.
- `pixi run test-mpi` runs the two-rank MPI variants of the C++ and Mojo tests
  from the default MPI-enabled `build/` tree.
- The public Mojo surface now uses move-only wrapper objects such as
  `AmrexRuntime`, `BoxArray`, `Geometry`, and `MultiFab`. The raw handle-level
  bindings remain available under `amrex.ffi`.

## Direct GPU Interop

The direct CUDA/HIP path is intentionally narrow:

1. Create or select a Mojo `DeviceContext`.
2. Enter `runtime.external_gpu_stream_scope(ctx, sync_on_exit=...)`.
3. Borrow tile data with `unsafe_device_array(...)` and launch Mojo kernels on
   `ctx.stream()` while AMReX calls in the same scope use that same stream.

Minimal shape:

```mojo
from amrex.runtime import AmrexRuntime
from std.gpu.host import DeviceContext

var runtime = AmrexRuntime()
var ctx = DeviceContext()
var stream_scope = runtime.external_gpu_stream_scope(ctx, sync_on_exit=False)

# Borrow device data from a GPU-backed MultiFab and launch Mojo kernels on
# ctx.stream() while AMReX uses the same external stream.
```

Important rules:

- This path is currently implemented only for CUDA and HIP AMReX backends.
- `unsafe_device_array(...)` returns pointer-and-shape metadata for
  device-accessible storage. Treat it as a device-only borrow. Do not use host
  indexing, `.fill()`, or any other host-side access on that value.
- The stream scope is the ordering boundary. Enter it before AMReX async work
  and before borrowing device pointers that Mojo kernels will touch.
- `sync_on_exit=False` avoids an unconditional stream synchronize when leaving
  the scope. Use it when you are deliberately building an async pipeline and
  synchronize explicitly before host reads or other host-visible effects.

The detailed design and caveats are documented in
`docs/mojo-amrex-direct-gpu-interop.md`.

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
  Treat those `TileF64View`, `Array4F64View`, `TileF32View`, and
  `Array4F32View` values as non-escaping borrows; they are only valid while the
  owning `MultiFab` or `MultiFabF32` and iterator state remain live.
- In the default CPU build, `MultiFab` storage remains host-accessible and the
  staged Mojo GPU helpers are still the portable path.
- In CUDA/HIP AMReX builds, `unsafe_device_array(...)` can borrow AMReX device
  storage directly, but only inside the intended GPU interop flow described
  above.
- If library discovery fails, the loader now reports the concrete path it tried
  and suggests either `pixi run build-capi`,
  `pixi run install-amrex`, or
  `AMREX_MOJO_LIBRARY_PATH=/path/to/libamrex_mojo_capi_3d.dylib`.

Focused usage notes for ownership, borrowing, and diagnostics live in
`docs/mojo-amrex-usage.md`.

## License

This repository is licensed under the BSD 3-Clause License. See `LICENSE`
for the full text.
