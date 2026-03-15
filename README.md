# mojo-amrex [proof-of-concept]

Mojo bindings to AMReX, built as a narrow C ABI plus Mojo wrapper types.

## What is here

- `src/capi/`: AMReX-backed C ABI
- `mojo/amrex/`: Mojo package exposed as top-level `amrex`
- `examples/`: host, GPU, direct GPU interop, and MPI examples
- `tests/`: C++ and Mojo test coverage
- `docs/`: usage notes and design details

## Current scope

The current MVP includes:

- runtime initialization and shutdown
- `BoxArray`, `DistributionMapping`, `Geometry`, and `MultiFab`
- tile iteration and zero-copy `Array4` borrows for host-accessible storage
- reductions, plotfile output, `fill_boundary`, and `parallel_copy_from`
- optional direct CUDA/HIP GPU interop through AMReX external streams
- runnable examples for host, staged GPU, direct GPU interop, and MPI flows

## Quickstart

From the repo root:

```bash
curl -fsSL https://pixi.sh/install.sh | sh
pixi run bootstrap
pixi shell
mojo examples/multifab.mojo
```

If `pixi` was just installed, restart your shell first so it is on `PATH`.

`pixi run bootstrap` configures the build, compiles the C ABI, and installs the
shared library plus `amrex.mojopkg` into the default pixi environment.

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
mojo examples/multifab.mojo
mojo examples/multifab_gpu.mojo
mojo examples/multifab_gpu_interop.mojo
mpiexec --oversubscribe --map-by slot -n 2 mojo examples/multifab_mpi.mojo
```

## Documentation

- `docs/implementation.md`: binding architecture, ownership model, and library loading
- `docs/mojo-amrex-usage.md`: usage notes, borrowing rules, and diagnostics
- `docs/mojo-amrex-direct-gpu-interop.md`: direct CUDA/HIP interop flow and caveats
- `docs/mojo-amrex-bindings-plan.md`: original design plan and background
- `tests/README.md`: test workflow details

## License

BSD 3-Clause. See `LICENSE`.
