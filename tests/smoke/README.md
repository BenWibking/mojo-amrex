# Smoke Examples

The repository now also has automated tests under `tests/README.md`, but the
manual example paths in `examples/Multifab/multifab.mojo`,
`examples/HeatEquation/heat_equation.mojo`,
`examples/Multifab/multifab_mpi.mojo` are still useful for an interactive
end-to-end run.

The intended smoke sequence is:

1. build the C ABI library
2. install the shared library and Mojo package into the active pixi env
3. initialize the runtime
4. construct `BoxArray`, `DistributionMapping`, `Geometry`, `MultiFab`, and `ParmParse`
5. iterate tiles from Mojo through `MFIter`
6. update one `MultiFab` while reading from another through `MultiFab.array(mfi)`
7. write a single-level plotfile from Mojo
8. shut down cleanly

Useful commands:

```bash
pixi run configure
pixi run build-capi
pixi run install-amrex
mojo examples/Multifab/multifab.mojo
mojo examples/HeatEquation/heat_equation.mojo
mpiexec --oversubscribe --map-by slot -n 2 mojo examples/Multifab/multifab_mpi.mojo
```

`pixi run build-capi` now refreshes the active env copy of
`libamrex_mojo_capi_3d` under `.pixi/envs/default/lib/` automatically, so bare
`mojo examples/...` invocations use the rebuilt library without an extra
install step.
