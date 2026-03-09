# mojo-amrex

Mojo bindings to AMReX, implemented as a narrow C ABI plus RAII-style Mojo objects.

The current repo contains:

- a design note in `docs/mojo-amrex-bindings-plan.md`
- a real AMReX-backed C ABI under `src/capi`
- a Mojo package under `mojo/amrex`
- an install path that exposes `amrex` as a top-level Mojo package in the active environment
- a working MultiFab smoke example in `examples/multifab_smoke.mojo`

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
pixi run build-capi
pixi run install-amrex
pixi run package-mojo
pixi run build-multifab-smoke
pixi run run-multifab-smoke
pixi run run-multifab-smoke-script
pixi run format-mojo
```

Notes:

- `pixi run bootstrap` is the one-shot setup path for a fresh checkout. It
  runs `configure`, `build-capi`, and `install-amrex`.
- By default the CMake build fetches AMReX from
  `https://github.com/AMReX-Codes/amrex/releases/download/26.03/amrex-26.03.tar.gz`
  and verifies the pinned SHA-256 before configuring a 3D, CPU-only,
  double-precision build suitable for the MVP bindings.
- To build against a local AMReX checkout instead, configure with
  `-DAMREX_MOJO_AMREX_SOURCE_DIR=/path/to/amrex`.
- `pixi run install-amrex` installs the C API library into the active env's
  `lib/` directory and installs `amrex.mojopkg` into the env's `lib/mojo/`
  directory, so bare commands like `mojo examples/multifab_smoke.mojo` work
  from the repo root inside `pixi shell` without `-I mojo`.
- The public Mojo surface now uses move-only wrapper objects such as
  `AmrexRuntime`, `BoxArray`, `Geometry`, and `MultiFab`. The raw handle-level
  bindings remain available under `amrex.ffi`.

## License

This repository is licensed under the BSD 3-Clause License. See `LICENSE`
for the full text.
