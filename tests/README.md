# Tests

The repository now has both automated tests and runnable examples under
`examples/Multifab/` and `examples/HeatEquation/`.

Automated test entry points:

1. `pixi run test-capi`
2. `pixi run test-mojo-runtime`
3. `pixi run test-mojo-multifab`
4. `pixi run test`

Coverage summary:

- `tests/capi/runtime_multifab_test.cpp` validates the C ABI directly,
  including null-handle diagnostics.
- `tests/mojo/runtime_geometry_test.mojo` validates runtime and geometry basics.
- `tests/mojo/multifab_functional_test.mojo` validates tile iteration, borrowed
  `Array4` access, reductions, arithmetic, `ParmParse`, and plotfile output.

The Mojo tests rebuild the C API before execution, which refreshes the active
pixi env copy of `libamrex_mojo_capi_3d` under `.pixi/envs/default/lib/`
automatically. They still exercise the current in-repo bindings rather than a
stale installed shared library.

Useful manual entry points:

- `mojo examples/Multifab/multifab.mojo`
- `mojo examples/Multifab/multifab_gpu.mojo`
- `mojo examples/HeatEquation/heat_equation.mojo`
- `mojo examples/HeatEquation/heat_equation_gpu.mojo`
- `mpiexec --oversubscribe --map-by slot -n 2 mojo examples/Multifab/multifab_mpi.mojo`
