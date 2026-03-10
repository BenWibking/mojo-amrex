# Tests

The repository now has both automated tests and a separate smoke example.

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

The Mojo tests rebuild the C API before execution, which now refreshes the
active pixi env's `lib/libamrex_mojo_capi_3d.dylib` automatically. They still
exercise the current in-repo bindings rather than a stale installed dylib.

The smoke example remains in `examples/multifab_smoke.mojo`. It is useful for a
manual end-to-end run but is no longer the only verification path.
