# Smoke Tests

This directory is reserved for the first executable smoke tests once the
vertical slice is wired:

1. build the C ABI library
2. package the Mojo bindings
3. initialize the runtime
4. construct `BoxArray`, `DistributionMapping`, and `MultiFab`
5. iterate a tile with `MFIter`
6. shut down cleanly

For now, the repository only provides the scaffold and the stub C ABI.
