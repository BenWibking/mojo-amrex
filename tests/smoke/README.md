# Smoke Example

The repository now also has automated tests under `tests/README.md`, but the
manual example paths in `examples/multifab.mojo`,
`examples/multifab_gpu.mojo`, `examples/multifab_gpu_interop.mojo`, and
`examples/multifab_mpi.mojo` are still useful for an interactive end-to-end
run.

`examples/multifab_gpu.mojo` demonstrates Mojo device kernels in
user code only. AMReX `MultiFab` storage remains host-resident in this repo,
and the example stages tile data through Mojo `DeviceBuffer`s before launch.
It is not AMReX GPU-runtime interop.

`examples/multifab_gpu_interop.mojo` is the direct CUDA/HIP interop example.
It requires an AMReX build with a CUDA or HIP backend and a Mojo-supported
accelerator so the two runtimes can share the same stream and device.

The intended smoke sequence is:

1. build the C ABI library
2. install the Mojo bindings into the active pixi env
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
mojo examples/multifab.mojo
mojo examples/multifab_gpu.mojo
mojo examples/multifab_gpu_interop.mojo
mpiexec --oversubscribe --map-by slot -n 2 mojo examples/multifab_mpi.mojo
```

`pixi run build-capi` now refreshes the active env's
`lib/libamrex_mojo_capi_3d.dylib` automatically, so bare `mojo examples/...`
invocations use the rebuilt library without an extra install step.
