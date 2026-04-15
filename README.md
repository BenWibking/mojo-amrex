# mojo-amrex [proof-of-concept]

<img src="docs/logo.png" alt="mojo-amrex logo" width="240">

Mojo bindings for AMReX, built as a narrow C ABI plus Mojo wrapper types.

## What is here

- `src/capi/`: AMReX-backed C ABI
- `mojo/amrex/`: Mojo package exposed as top-level `amrex`
- `examples/`: `Multifab` and `HeatEquation` examples for host, direct GPU interop, and MPI workflows
- `tests/`: C++ and Mojo test coverage
- `docs/`: usage notes and design details

## Current scope

The current MVP includes:

- runtime initialization and shutdown
- `BoxArray`, `DistributionMapping`, `Geometry`, and `MultiFab`
- tile iteration and zero-copy `Array4` borrows for host-accessible storage
- portable staged GPU helper types for host-backed `Array4F32View` data
- reductions, plotfile output, `fill_boundary`, and `parallel_copy_from`
- optional direct CUDA/HIP GPU interop through AMReX external streams
- runnable examples for host, heat-equation, direct GPU interop, and MPI flows

## Quickstart

From the repo root:

```bash
curl -fsSL https://pixi.sh/install.sh | sh
pixi run bootstrap
pixi shell
mojo examples/Multifab/multifab.mojo
```

If `pixi` was just installed, restart your shell first so it is on `PATH`.

`pixi run bootstrap` configures the build, compiles the C ABI, and installs the
shared library plus `amrex.mojopkg` into the default pixi environment.
If CMake can see a HIP toolchain, `AUTO` now tries to fill
`AMReX_AMD_ARCH=<gfx*>` from `rocminfo` before selecting HIP; otherwise it
falls back to a CPU-only AMReX build.

On some HPC login nodes, Pixi can fail before task execution with a Rayon thread
pool error such as `failed to initialize global rayon pool` or `Resource
temporarily unavailable`. In that case, rerun with lower Pixi concurrency:

```bash
RAYON_NUM_THREADS=1 pixi run --frozen bootstrap
```

or:

```bash
pixi run --concurrent-solves 1 --frozen bootstrap
```

That failure happens inside Pixi's solver/fetch path, not in this repository's
CMake or Mojo build logic.

## Common commands

Setup and build:

```bash
pixi run bootstrap
pixi run configure
pixi run build-capi
pixi run install-amrex
```

Tests:

```bash
pixi run test
pixi run test-mpi
```

Formatting:

```bash
pixi run format-mojo
```

Examples:

```bash
mojo examples/Multifab/multifab.mojo
mojo examples/Multifab/multifab_gpu.mojo
mojo examples/HeatEquation/heat_equation.mojo
mojo examples/HeatEquation/heat_equation_gpu.mojo
mpiexec --oversubscribe --map-by slot -n 2 mojo examples/Multifab/multifab_mpi.mojo
```

## Documentation

- `docs/implementation.md`: binding architecture, ownership model, and library loading
- `docs/mojo-amrex-usage.md`: usage notes, borrowing rules, and diagnostics
- `docs/mojo-amrex-direct-gpu-interop.md`: direct CUDA/HIP interop flow and caveats
- `docs/mojo-amrex-bindings-plan.md`: original design plan and background
- `tests/README.md`: test workflow details

## License

BSD 3-Clause. See `LICENSE`.
