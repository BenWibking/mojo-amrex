# mojo-amrex

Scaffold repository for Mojo bindings to AMReX.

The current repo contains:

- a design note in `docs/mojo-amrex-bindings-plan.md`
- a buildable C ABI stub library under `src/capi`
- a Mojo package scaffold under `mojo/amrex`
- placeholders for examples and smoke tests

The intent is to grow this in vertical slices:

1. C ABI for core AMReX objects
2. Mojo FFI loader and raw symbol bindings
3. safe Mojo wrappers under `amrex.space3d`

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
pixi run package-mojo
pixi run format-mojo
```

Notes:

- The current C API is intentionally a stub. It defines the ABI and file
  boundaries, but most functions return `AMREX_MOJO_STATUS_UNIMPLEMENTED`.
- `AMREX_MOJO_ENABLE_AMREX=ON` is reserved for wiring the shared library to a
  real AMReX build in a later step.
