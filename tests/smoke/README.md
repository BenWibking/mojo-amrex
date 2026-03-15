# Smoke Examples

The repository now also has automated tests under `tests/README.md`, but the
manual example paths in `examples/Multifab/multifab.mojo`,
`examples/Multifab/multifab_gpu.mojo`,
`examples/HeatEquation/heat_equation.mojo`,
`examples/HeatEquation/heat_equation_gpu.mojo`, and
`examples/Multifab/multifab_mpi.mojo` are still useful for an interactive
end-to-end run.

`examples/Multifab/multifab_gpu.mojo` is the smaller direct CUDA/HIP interop
example. It shares the active Mojo stream with AMReX and launches Mojo kernels
directly over AMReX-managed device-accessible `MultiFabF32` storage.

`examples/HeatEquation/heat_equation_gpu.mojo` is the larger direct interop
example. It applies the same stream-sharing path to the heat-equation update
loop and bundled `heat_equation_gpu.inputs` driver.

The portable staged path still exists in `amrex.space3d.gpu` through
`StagedArray4F32` and `StagedTileF32`, but there is currently no dedicated
standalone staged-GPU example script in `examples/`.

The intended smoke sequence is:

1. build the C ABI library
2. install the shared library and Mojo package into the active pixi env
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
pixi run install-amrex
mojo examples/Multifab/multifab.mojo
mojo examples/Multifab/multifab_gpu.mojo
mojo examples/HeatEquation/heat_equation.mojo
mojo examples/HeatEquation/heat_equation_gpu.mojo
mpiexec --oversubscribe --map-by slot -n 2 mojo examples/Multifab/multifab_mpi.mojo
```

`pixi run build-capi` now refreshes the active env copy of
`libamrex_mojo_capi_3d` under `.pixi/envs/default/lib/` automatically, so bare
`mojo examples/...` invocations use the rebuilt library without an extra
install step.
