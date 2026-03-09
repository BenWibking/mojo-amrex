# Smoke Tests

The repository now has a working smoke path in `examples/vertical_slice.mojo`.
The intended smoke sequence is:

1. build the C ABI library
2. package the Mojo bindings
3. initialize the runtime
4. construct `BoxArray`, `DistributionMapping`, and `MultiFab`
5. iterate tiles from Mojo and fill through the exported `Array4` view
6. shut down cleanly

Useful commands:

```bash
pixi run build-capi
pixi run package-mojo
pixi run build-vertical-slice
pixi run run-vertical-slice
```
