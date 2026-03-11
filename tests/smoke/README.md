# Smoke Example

The repository now also has automated tests under `tests/README.md`, but the
manual smoke paths in `examples/multifab_smoke.mojo` and
`examples/multifab_smoke_mojo_gpu.mojo` are still useful for an interactive
end-to-end run.

`examples/multifab_smoke_mojo_gpu.mojo` demonstrates Mojo device kernels in
user code only. AMReX `MultiFab` storage remains host-resident in this repo,
and the example stages tile data through Mojo `DeviceBuffer`s before launch.
It is not AMReX GPU-runtime interop.

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
pixi run install-mojo-package
pixi run install-amrex
pixi run build-multifab-smoke
pixi run run-multifab-smoke
pixi run run-multifab-smoke-script
pixi run build-multifab-smoke-mojo-gpu
pixi run run-multifab-smoke-mojo-gpu
pixi run run-multifab-smoke-mojo-gpu-script
```

`pixi run build-capi` now refreshes the active env's
`lib/libamrex_mojo_capi_3d.dylib` automatically, so `pixi run install-capi` is
only needed when you specifically want the rest of the CMake install artifacts.
