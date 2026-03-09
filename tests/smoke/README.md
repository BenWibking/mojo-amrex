# Smoke Tests

The repository now has a working smoke path in `examples/multifab_smoke.mojo`.
The intended smoke sequence is:

1. build the C ABI library
2. package the Mojo bindings
3. initialize the runtime
4. construct `BoxArray`, `DistributionMapping`, `Geometry`, `MultiFab`, and `ParmParse`
5. iterate tiles from Mojo through `MultiFab.for_each_tile`
6. write a single-level plotfile from Mojo
7. shut down cleanly

Useful commands:

```bash
pixi run configure
pixi run build-capi
pixi run install-capi
pixi run install-mojo-package
pixi run install-amrex
pixi run build-multifab-smoke
pixi run run-multifab-smoke
pixi run run-multifab-smoke-script
```
