# Heat equation examples loop over `tile.valid_box` inside a tiled MFIter, redoing each fab's work once per tile

**Severity: Medium** (examples produce correct results but do ~16x redundant work on CPU and write the same cells concurrently from multiple GPU streams)

## Explanation

The C API snapshots tiles with tiling enabled
(`populate_tiles` in `src/capi/multifab.cpp:195` uses
`MFItInfo().EnableTiling()`). On CPU 3D builds the default tile size is
`(1024000, 8, 8)`, so a 32^3 fab is split into 16 tiles, each sharing the same
`valid_box`.

Both heat equation examples use the per-tile `valid_box` as the kernel launch box:

- `examples/HeatEquation/heat_equation.mojo:97` (`var bx = tile.valid_box` in the
  init loop) and `:131` (update loop)
- `examples/HeatEquation/heat_equation_vis.mojo:29` (`initialize_phi`), `:123`
  (`slice_array`, which re-copies the same plane once per tile), and `:138`
  (`step`)

Each iteration of `for tile in mfi:` therefore processes the *entire fab*, not the
tile, so every cell is computed `tiles_per_fab` times (16x with the default
inputs `n_cell=128`, `max_grid_size=32`). The results stay correct only because
the kernels are idempotent (they read `phi_old` and write `phi_new`). On a GPU
build, tiles are round-robined across streams (`MFIter.__next__`), so the
duplicate launches also write the same `phi_new` cells concurrently from
different streams — benign today only because every writer stores the same value.

The other examples and the functional test correctly use `tile.tile_box`.

## Proposed patch

Use the tile box for the kernel launches, mirroring
`examples/Multifab/multifab.mojo` and the AMReX original's
`mfi.tilebox()`:

```mojo
for tile in mfi:
    var bx = tile.tile_box
    ...
    mfi.parallel_for(initialize_cell, bx)
```

In `heat_equation_vis.mojo:slice_array`, either iterate `tile.tile_box` (each
tile contributes only its own cells) or hoist the plane copy out of the tile loop
so it runs once per fab.
