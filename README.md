# mojo-amrex

Mojo bindings to AMReX, implemented as a narrow C ABI plus a Mojo FFI layer.

The current repo contains:

- a design note in `docs/mojo-amrex-bindings-plan.md`
- a real AMReX-backed C ABI under `src/capi`
- a Mojo package under `mojo/amrex`
- a working vertical-slice example in `examples/vertical_slice.mojo`

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
pixi run package-mojo
pixi run build-vertical-slice
pixi run run-vertical-slice
pixi run format-mojo
```

Notes:

- By default the CMake build pulls AMReX from `../amrex` and configures a 3D,
  CPU-only, double-precision build suitable for the MVP bindings.
- The current Mojo surface is intentionally pragmatic: opaque handles plus
  typed helper structs and tile views. It validates the binding architecture
  without committing to the final ownership ergonomics yet.
