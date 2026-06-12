# Free-function `ParallelFor` loads the default library, ignoring the runtime's library path

**Severity: Medium-Low** (breaks GPU dispatch when `AmrexRuntime` was constructed with an explicit library path; adds per-call `dlopen` overhead everywhere)

## Explanation

The standalone `ParallelFor(body, tile_box)` overload
(`mojo/amrex/space3d/parallelfor.mojo:56`) begins with:

```mojo
var lib = load_default_library()
var backend = gpu_backend(lib)
```

`AmrexRuntime` supports explicit library paths (`AmrexRuntime(path)`,
`AmrexRuntime(path, device_id)`, ...), and all other wrappers route calls through
the `RuntimeLease`'s stored `lib`. This function instead re-resolves
`AMREX_MOJO_LIBRARY_PATH`/`CONDA_PREFIX`/build-dir defaults on *every call*:

- If the runtime was created from a non-default path, `load_default_library()`
  dlopens a different shared object with its own static state. That copy of
  AMReX is uninitialized, so on a GPU build `gpu_stream()` fails (or, worse,
  `gpu_backend()` of the wrong library disagrees with the runtime actually in
  use). If no default library exists on disk, the call raises even though a
  perfectly good runtime is loaded.
- Even in the default-path case, each tile-loop iteration pays a
  `dlopen`/`dlclose` round trip plus environment lookups (`heat_equation_vis.mojo:156`
  calls this once per tile per step).

`MFIter.parallel_for` does this correctly by using the iterator's
`runtime[].lib`.

## Proposed patch

The CPU fallback path needs no library at all; only the GPU path does. Restrict
the free function to contexts that can supply one:

1. Change the GPU branch to require an explicit source of truth — e.g. add an
   overload `ParallelFor(ref runtime: AmrexRuntime, body, tile_box)` (or accept a
   `RuntimeLease`) that uses `runtime._lease()[].lib`, and
2. In the zero-argument overload, drop the GPU probe and always run
   `_parallel_for_cpu`, documenting that GPU execution requires either the
   runtime-taking overload or `MFIter.parallel_for`.

Callers in the examples (`examples/Multifab/multifab.mojo:65`,
`examples/HeatEquation/heat_equation_vis.mojo:40,156`) already have the runtime
or an `MFIter` in scope and can switch to `mfi.parallel_for`.
