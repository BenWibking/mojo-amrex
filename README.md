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

- By default the CMake build pulls AMReX from `../amrex` and configures a 3D,
  CPU-only, double-precision build suitable for the MVP bindings.
- `pixi run install-amrex` installs the C API library into the active env's
  `lib/` directory and installs `amrex.mojopkg` into the env's `lib/mojo/`
  directory, so bare commands like `mojo examples/multifab_smoke.mojo` work
  from the repo root without `-I mojo`.
- The public Mojo surface now uses move-only wrapper objects such as
  `AmrexRuntime`, `BoxArray`, `Geometry`, and `MultiFab`. The raw handle-level
  bindings remain available under `amrex.ffi`.

## License

This repository is licensed under the BSD 3-Clause License. See `LICENSE`
for the full text.
