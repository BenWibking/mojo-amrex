# Smoke Example

The repository now also has automated tests under `tests/README.md`, but the
manual smoke paths in `examples/multifab_smoke.mojo` and, on Apple Silicon,
`examples/multifab_smoke_apple_gpu.mojo` are still useful for an interactive
end-to-end run.

The intended smoke sequence is:

1. build the C ABI library
2. package the Mojo bindings
3. initialize the runtime
4. construct `BoxArray`, `DistributionMapping`, `Geometry`, `MultiFab`, and `ParmParse`
5. iterate tiles from Mojo through both `MultiFab.for_each_tile` and `MFIter`
6. update one `MultiFab` while reading from another through `MultiFab.array(mfi)`
7. write a single-level plotfile from Mojo
8. shut down cleanly

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
pixi run build-multifab-smoke-apple-gpu
pixi run run-multifab-smoke-apple-gpu
pixi run run-multifab-smoke-apple-gpu-script
```
