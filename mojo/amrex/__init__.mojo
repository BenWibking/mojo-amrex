"""Top-level Mojo package for AMReX bindings.

This package is intentionally thin in the initial scaffold. The real work will
land in three layers:

1. runtime loading of the C ABI shared library
2. raw FFI bindings for exported C symbols
3. safe wrappers in `amrex.space3d`

See `docs/mojo-amrex-bindings-plan.md` for the implementation plan.
"""
