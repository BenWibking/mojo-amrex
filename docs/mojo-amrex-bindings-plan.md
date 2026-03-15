# Mojo Bindings Plan for AMReX

Last updated: 2026-03-15

## Goal

Create a set of Mojo bindings for AMReX in this repository, modeled on the
useful parts of `../pyamrex`, while respecting Mojo's C FFI model and AMReX's
native C++ API.

The target is not a literal port of `pyamrex` internals. The target is a Mojo
package that exposes a similar user-facing workflow for core AMReX objects and
data access.

## Summary

The recommended architecture is:

1. `AMReX C++`
2. `extern "C"` shim library with a narrow, explicit ABI
3. Mojo wrappers built on Mojo FFI and Mojo's value lifecycle model

This is the right boundary because `pyamrex` is a pybind11 layer over C++, but
Mojo's FFI is designed around C ABI calls. Direct C++ binding from Mojo would
be brittle and difficult to maintain. A C shim gives us stable symbol names,
explicit ownership, and a place to flatten AMReX types into FFI-safe handles
and structs.

The wrapper layer must also respect Mojo's value destruction rules. In
particular:

- destruction can happen as soon as a value is no longer used, not only at the
  lexical end of scope
- owner and borrower relationships must be represented in Mojo types, not only
  documented in comments
- opaque-handle wrappers should be move-only by default unless the C ABI
  provides an explicit clone operation
- destructors must be infallible and safe to call on moved-from or null handles

## Current Status

The repository has already completed the initial MVP bring-up described in this
plan:

- Phase 0 bootstrap is in place
- Phase 1 value types and runtime basics are implemented
- Phase 2 `MultiFab` and tile iteration are implemented
- Phase 3 explicit `MFIter`, minimal `ParmParse`, and plotfile smoke path are
  implemented
- Phase 4 quality and ergonomics is implemented for the MVP binding surface:
  move-only owner wrappers, wrapper-side live-handle diagnostics, automated
  tests, and focused user documentation are in place

That means the first vertical slice is no longer the next task. The main work
remaining is:

- deeper Phase 5 expansion items such as broader MPI coverage, GPU, particles,
  and broader dimensional coverage

Since this plan was written, the repo has also gained an opt-in direct
CUDA/HIP GPU interop path based on AMReX external streams. Treat
`docs/mojo-amrex-direct-gpu-interop.md` as the current GPU status document; the
rest of this file remains useful as background on the original binding
architecture and scope decisions.

An initial MPI slice is now implemented:

- optional MPI-enabled build and test path through `AMREX_MOJO_ENABLE_MPI`
- OpenMPI-backed pixi environment and MPI test tasks
- runtime initialization through `argc`, `argv`, and `use_parmparse` in both
  the C ABI and Mojo wrappers
- `MultiFab.fill_boundary(...)` and `MultiFab.parallel_copy_from(...)`
- two-rank C ABI and Mojo regression coverage
- a runnable MPI ghost-exchange example at
  `examples/Multifab/multifab_mpi.mojo`

## Key Findings

### 1. `pyamrex` is a feature catalog, not an MVP target

`../pyamrex` exposes a large API surface:

- `pyAMReX.cpp` registers bindings across Base, AmrCore, Particle, and utility
  subsystems.
- `docs/source/usage/api.rst` shows broad coverage including `IntVect`, `Box`,
  `BoxArray`, `Geometry`, `DistributionMapping`, `MultiFab`, `Array4`,
  `ParmParse`, `ParallelDescriptor`, particles, and plotfile utilities.
- The generated 3D stub file
  `../pyamrex/src/amrex/space3d/amrex_3d_pybind/__init__.pyi` is large enough
  to confirm that parity is a substantial project, not a first milestone.

Conclusion: use `pyamrex` to prioritize the binding surface, but do not try to
match it all in the first implementation.

### 2. Mojo should bind to C ABI, not directly to C++

The Mojo FFI model is centered on:

- compile-time foreign function calls via `external_call`
- runtime-loaded shared libraries via `OwnedDLHandle`
- C string interop via the standard FFI string utilities

That strongly favors a C ABI layer with opaque pointers and POD structs.

### 3. AMReX already contains useful C-facing wrappers

AMReX's `Src/F_Interfaces` code provides existing `extern "C"` functions for a
number of core objects, including:

- initialization/finalization
- `BoxArray`
- `DistributionMapping`
- `Geometry`
- `MultiFab`
- `MFIter`
- some `AmrCore` and particle support

Representative files:

- `../amrex/Src/F_Interfaces/Base/AMReX_init_fi.cpp`
- `../amrex/Src/F_Interfaces/Base/AMReX_boxarray_fi.cpp`
- `../amrex/Src/F_Interfaces/Base/AMReX_distromap_fi.cpp`
- `../amrex/Src/F_Interfaces/Base/AMReX_geometry_fi.cpp`
- `../amrex/Src/F_Interfaces/Base/AMReX_multifab_fi.cpp`
- `../amrex/Src/F_Interfaces/Particle/AMReX_particlecontainer_fi.cpp`

These are good reference implementations and may be partially reusable.

### 4. Reusing all of `F_Interfaces` is not the same as having a Mojo API

AMReX only builds `Src/F_Interfaces` when `AMReX_FORTRAN_INTERFACES=ON`, and
that path includes Fortran sources as well as C++ wrapper sources. For a Mojo
binding project, enabling that whole stack just to obtain a few C entry points
is unnecessary coupling.

Conclusion: reuse code patterns and selected wrappers where practical, but own a
Mojo-focused C shim library in this repository.

## Recommended Scope

### First milestone

Implement a usable 3D, CPU-only, double-precision binding set for core mesh and
field operations:

- `AmrexRuntime`
- runtime state query
- `ParallelDescriptor` basics
- `IntVect`
- `Box`
- `BoxArray`
- `DistributionMapping`
- `Geometry`
- `MultiFab`
- `Array4<Real>` tile views
- callback-based tile iteration
- minimal `ParmParse`
- plotfile write smoke path

This is enough to support a real AMReX workflow in Mojo:

- create runtime root owner
- define domain and geometry
- create a `BoxArray`
- create a `DistributionMapping`
- allocate a `MultiFab`
- iterate tiles through a borrowing-safe API
- access tile data through `Array4`
- do reductions or write a plotfile

### Explicit non-goals for the first milestone

- full `pyamrex` API parity
- 1D and 2D builds
- GPU array interop
- DLPack
- particles
- the full `ParmParse` surface
- `AmrMesh` or custom `AmrCore` subclassing

Those can follow after the core ABI and ownership model are proven.

## Proposed Architecture

### Layer 1: C++ shim library

Build a shared library, for example `amrex_mojo_capi_3d`, that links against
AMReX and exports a narrow `extern "C"` ABI.

Design rules:

- Use opaque handles for owning C++ objects.
- Use POD structs for small value types.
- Return status codes for fallible operations.
- Use out-parameters instead of exceptions across the C ABI.
- Keep object ownership explicit.
- Do not expose STL or C++ template types directly.

Suggested type split:

- Opaque handles:
  - `amrex_mojo_boxarray_t`
  - `amrex_mojo_distmap_t`
  - `amrex_mojo_geometry_t`
  - `amrex_mojo_multifab_t`
  - `amrex_mojo_mfiter_t`
  - `amrex_mojo_parmparse_t`
- POD structs:
  - `amrex_mojo_intvect_3d`
  - `amrex_mojo_box_3d`
  - `amrex_mojo_realbox_3d`
  - `amrex_mojo_array4_view_f64`
  - `amrex_mojo_status`

`Array4` should be exposed as a non-owning view struct containing:

- data pointer
- low bounds
- high bounds
- strides in elements
- number of components

That is the key mechanism for zero-copy tile access from Mojo.

### Layer 2: Mojo FFI loader and low-level bindings

Create a Mojo module that loads the shared library and binds raw C symbols.

Recommended starting approach:

- use `OwnedDLHandle` to load the library at runtime
- resolve symbols from a predictable build/install location
- keep the raw C signatures in one low-level Mojo module
- keep the loaded library alive for at least as long as any wrapper that may
  call into it

Why start with runtime loading:

- it is easier to bootstrap in a new repository
- it avoids premature toolchain friction
- it keeps library discovery explicit during early iteration

If later profiling shows call overhead matters, selected hot-path entry points
can move to compile-time `external_call`.

### Layer 3: Safe Mojo wrappers

Build user-facing Mojo types on top of the raw FFI layer:

- `AmrexRuntime`
- `IntVect3D`
- `Box3D`
- `BoxArray`
- `DistributionMapping`
- `Geometry`
- `MultiFab`
- `Array4F64View`
- `TileF64View`
- `ParmParse`

Wrapper rules:

- `AmrexRuntime` is the root owner for AMReX process state and the FFI library
  handle
- every owning AMReX wrapper retains a dependency on `AmrexRuntime` so the
  runtime cannot be destroyed while AMReX objects still exist
- owning Mojo types destroy the C++ object in `__del__`
- owning wrappers are move-only unless the C ABI provides an explicit clone
  operation
- moved-from owning wrappers must become null and safe to destroy
- non-owning views never free memory
- borrowed values encode their dependency on owners in the Mojo type system,
  either through origin-based borrowing or by retaining the required owner
  internally
- tile iteration APIs should prefer non-escaping callback-style borrows in the
  first milestone
- bounds and null checks happen in the Mojo layer where practical
- compile-time AMReX configuration is surfaced explicitly

The wrapper API should resemble `pyamrex` where it improves ergonomics, but it
does not need to mimic Python naming exactly.

## API Strategy

### Mirror concepts, not pybind11 mechanics

The useful pieces to mirror from `pyamrex` are:

- object model
- common constructors
- common property names
- iteration model for `MFIter`
- tile-level data access through `MultiFab.array(mfi)`

Things not worth copying directly:

- Python-only extension patterns
- dynamic attribute behavior
- NumPy and CuPy protocols
- pybind11-specific overload behavior

### Suggested first-pass Mojo API

```mojo
from amrex.space3d import *

def fill_tile[
    owner_origin: Origin[mut=True]
](tile: TileF64View[owner_origin]) raises:
    tile.array().fill(42.0)


def main() raises:
    var rt = AmrexRuntime()

    let small = IntVect3D(0, 0, 0)
    let big = IntVect3D(63, 63, 63)
    let domain = Box3D(small, big)

    var ba = BoxArray(rt, domain)
    ba.max_size(32)

    let dm = DistributionMapping(rt, ba)
    let geom = Geometry(rt, domain)
    var mf = MultiFab(rt, ba, dm, n_comp=1, n_grow=1)

    mf.for_each_tile[fill_tile]()
```

This should be the user experience target for the first milestone.

## C API Design Notes

### Initialization

Do not model AMReX runtime state as a pair of free-standing public functions in
the Mojo layer. Mojo can destroy values as soon as they are no longer used, so
an explicit `finalize()` call can race with later wrapper destruction.

Instead, expose a root runtime object:

- C ABI:
  - `amrex_mojo_runtime_create(argc, argv, use_parmparse)`
  - `amrex_mojo_runtime_create_default()`
  - `amrex_mojo_runtime_destroy(runtime)`
  - `amrex_mojo_runtime_initialized(runtime)`
- Mojo API:
  - `AmrexRuntime()`
  - `AmrexRuntime(argv, use_parmparse=False)`
  - `AmrexRuntime(path, argv, use_parmparse=False)`
  - `AmrexRuntime.initialized()`

All owning AMReX wrappers are created from an `AmrexRuntime` and retain a
runtime dependency in their Mojo representation. That makes the runtime a true
root owner rather than a convention. `AmrexRuntime.__del__()` performs
finalization only when no wrappers that depend on it remain alive.

Avoid passing raw AMReX callback hooks in the first version unless there is a
clear need.

### Status and error reporting

C++ exceptions must not cross the C boundary. Use one of these patterns:

- integer status code + global thread-local error message
- status struct containing code and message pointer

For the first version, a small integer error code plus a
`amrex_mojo_last_error_message()` accessor is sufficient.

### Lifetime management

Every owning constructor needs a matching destroy function:

- `*_create`
- `*_clone` if needed
- `*_destroy`

Ownership and borrowing must be represented in the Mojo API, not merely
documented. The lifecycle rules for the binding layer should be:

- small value types such as `IntVect3D` and `Box3D` are copied by value
- opaque AMReX owners such as `BoxArray`, `DistributionMapping`, `Geometry`,
  `MultiFab`, and `ParmParse` are move-only Mojo wrappers by default
- copied wrappers are only allowed when the C ABI provides a true deep-copy
  operation
- destructors must be infallible and null-safe because they run from `__del__`
- borrowed views must encode the owner relationship in Mojo types so they
  cannot outlive the data they refer to
- non-owning views should return copied metadata plus a borrowed data pointer,
  not a second borrowed opaque handle, wherever feasible

Concrete API guidance:

- `Geometry.domain()` should return a copied `Box3D`
- `MultiFab.box_array()` should return copied metadata or a copied `BoxArray`,
  not a borrowed `BoxArray` handle
- `MultiFab.array(...)` should return an `Array4F64View` whose lifetime is tied
  to the owning `MultiFab` and, if necessary, any iterator state used to compute
  the tile
- first-milestone tile access should prefer a callback-style API such as
  `for_each_tile` so the tile borrow cannot escape its valid scope

It is better to copy small objects than to export tricky borrowed references
without type-enforced lifetime guarantees.

### Array view semantics

`Array4<Real>` is the most important data path.

The first version should support:

- mutable host pointer access on CPU
- explicit shape metadata copied into the view
- explicit stride metadata copied into the view
- helper methods in Mojo for indexing and fill operations
- a view type whose borrow is tied to the `MultiFab` tile lifetime

The first version should not try to reproduce:

- NumPy `__array_interface__`
- CUDA `__cuda_array_interface__`
- DLPack

### GPU ownership and async execution

Current repo status:

- AMReX GPU backends are intentionally disabled.
- `MultiFab` storage stays host-resident from the AMReX side.
- Mojo device kernels are still viable in user code, but only by explicitly
  staging AMReX tile data through Mojo `DeviceBuffer`s.

The original design intent was to preserve AMReX's native ownership model
instead of replacing it with Mojo-native buffer ownership. In practice, that
interop is not complete because AMReX-managed device allocation, borrowed
`Array4` device views, and stream/runtime composition between AMReX and Mojo
are not wired up well enough yet.

See `docs/mojo-amrex-direct-gpu-interop.md` for the concrete proposal for that
deferred direct path. The short version is that AMReX should remain the owner
of both device memory and stream selection, while Mojo adapts its kernel
launches to the current AMReX stream.

That leaves two distinct execution models:

- current supported path: host-backed `MultiFab` plus explicit staging into
  Mojo buffers for user-launched kernels
- deferred path: direct AMReX GPU-runtime interop with AMReX-owned device
  allocation and stream coordination

Until the deferred path is properly defined and tested, this repo should not
present AMReX GPU support as available.

## Build System Plan

### CMake

Add a CMake build that:

- builds or finds AMReX
- compiles the C shim shared library
- installs or copies the library into a location the Mojo package can find

Recommended AMReX options for the first milestone:

- `AMReX_SPACEDIM=3`
- `AMReX_PRECISION=DOUBLE`
- `AMReX_MPI=OFF` by default, with an optional MPI build enabled through the
  repository's `AMREX_MOJO_ENABLE_MPI` toggle
- `AMReX_GPU_BACKEND=NONE`
- `AMReX_PARTICLES=OFF` initially

This keeps the ABI small and the bring-up path short.

### Repository structure

Suggested layout:

```text
docs/
  mojo-amrex-bindings-plan.md
cmake/
src/
  capi/
    amrex_mojo_capi.h
    init.cpp
    box.cpp
    boxarray.cpp
    distmap.cpp
    geometry.cpp
    multifab.cpp
    mfiter.cpp
    parmparse.cpp
mojo/
  amrex/
    __init__.mojo
    loader.mojo
    ffi.mojo
    runtime.mojo
    space3d/
      __init__.mojo
      types.mojo
      box.mojo
      boxarray.mojo
      geometry.mojo
      multifab.mojo
      mfiter.mojo
      tile.mojo
tests/
  smoke/
```

The exact top-level names can change, but separating `capi` from Mojo wrappers
is important.

## Phased Implementation Plan

### Phase 0: bootstrap (completed)

Deliverables:

- repository layout
- CMake build for shared library
- minimal Mojo package layout
- library loading via `OwnedDLHandle`
- `AmrexRuntime`
- one working smoke test

Exit criteria:

- Mojo code can load the shared library
- `AmrexRuntime` creation and destruction succeed
- the loaded shared library stays alive for the duration of runtime-owned values

### Phase 1: value types and runtime basics (completed)

Deliverables:

- move-only owner wrapper pattern
- `IntVect3D`
- `Box3D`
- `BoxArray`
- `DistributionMapping`
- `Geometry`
- `ParallelDescriptor` basics

Exit criteria:

- create and inspect domain objects from Mojo
- verify sizes, bounds, and box splitting behavior

### Phase 2: `MultiFab` and tile iteration (completed)

Deliverables:

- `MultiFab`
- `Array4F64View`
- callback-based tile iteration
- core reductions: `min`, `max`, `sum`, `norm0`, `norm1`, `norm2`
- basic arithmetic: `set_val`, `plus`, `mult`, `copy`

Exit criteria:

- allocate a `MultiFab`
- iterate over tiles through a borrowing-safe API
- fill and modify data
- validate results against expected reductions

### Phase 3: explicit iterator API, utility, and I/O (completed)

Deliverables:

- `MFIter`
- minimal `ParmParse`
- plotfile write smoke path

Exit criteria:

- `MFIter` supports `MultiFab.array(mfi)` across compatible `MultiFab`
  layouts without exposing raw C++ iterator lifetime hazards
- configure simple values through `ParmParse`
- write a plotfile from Mojo

### Phase 4: quality and ergonomics (completed)

Deliverables:

- explicit decision to keep owner wrappers move-only for the MVP
- safer wrapper APIs with live-handle diagnostics
- better error messages
- docs and examples
- broader test coverage

Exit criteria:

- enough stability to use bindings in a small AMReX-driven workflow

### Phase 5: expansion (in progress)

Potential additions:

- 1D and 2D builds
- broader MPI support beyond the initial slice
  - custom communicators instead of only `MPI_COMM_WORLD`
  - more `ParallelDescriptor` collectives and synchronization utilities
  - additional `MultiFab` communication helpers as real workflows require them
- GPU builds using AMReX-owned `MultiFab` storage allocated from
  `The_Async_Arena()`
- DLPack or other array interop
- particles
- more `AmrCore` functionality

Completed MPI slice:

- optional MPI build/test path and OpenMPI pixi environment
- runtime construction from `argv` with `use_parmparse`
- `MultiFab.fill_boundary(...)`
- `MultiFab.parallel_copy_from(...)`
- two-rank C ABI and Mojo coverage
- MPI example exercising ghost exchange and copy

## Testing Plan

Use `pyamrex` tests as the prioritization source, not as a direct porting
requirement.

Highest-priority tests to recreate first:

- `test_intvect.py`
- `test_box.py`
- `test_boxarray.py`
- `test_geometry.py`
- `test_multifab.py`
- `test_array4.py`

These cover the most important value types and data access paths.

Recommended test layers:

- C++ C-ABI tests for the shim
- Mojo smoke tests for library loading and ownership
- Mojo functional tests for core AMReX workflows
- MPI variants of the C++ and Mojo tests for communication-sensitive paths

The test strategy should verify both behavior and lifetime correctness.

## Risks and Design Traps

### 1. Trying to bind too much too early

The fastest way to stall the project is to target full `pyamrex` parity from the
start. The initial slice should be small and useful.

### 2. Borrowed lifetimes that are not explicit

`MultiFab`, `MFIter`, and `Array4` relationships are easy to get wrong. The
wrapper layer must make ownership and borrowing obvious in the type system, not
just in documentation.

### 3. Runtime shutdown ordering

If AMReX finalization happens before all owner wrappers are destroyed, later
destructors may call into a shut-down runtime. The binding layer must root all
owners under `AmrexRuntime` and make finalization happen from its destructor.

### 4. Premature GPU interop

GPU support is important long-term, but it is not the right first target for a
new FFI stack. CPU correctness should come first. When GPU support is added,
prefer AMReX-managed allocation via `The_Async_Arena()` over redesigning
`MultiFab` ownership around Mojo `DeviceBuffer`, and treat stream coordination
as the main integration risk. The current public Mojo GPU API appears to manage
its own streams rather than adopt external AMReX stream handles, so boundary
synchronization may be required unless lower-level interop becomes available.
`docs/mojo-amrex-direct-gpu-interop.md` captures the proposed path for closing
that gap by importing the current AMReX stream into Mojo rather than trying to
make AMReX adopt Mojo-owned streams.

### 5. Depending too heavily on AMReX's Fortran interface build path

That path is useful as a reference and may provide reusable code, but it is not
the right architectural center for a Mojo project.

### 6. Leaking C++ exceptions across the ABI

The shim must translate errors to C-compatible results. This should be enforced
from the beginning.

## Estimated Effort

Rough estimates:

- bootstrap + MVP core: 1 to 2 weeks
- solid core binding set without particles or GPU: 3 to 6 weeks
- broad `pyamrex`-like coverage: significantly more, depending on how far MPI,
  particles, and GPU interop are taken

These estimates assume reuse of AMReX and `pyamrex` behavior as design guides,
not literal code translation.

## Recommended Next Step

Phase 4 is complete for the current 3D CPU binding layer, and the first MPI
slice of Phase 5 is now in place. The next implementation step is to choose
whether the next workflow needs broader MPI coverage or whether the project
should move to the next Phase 5 expansion target.

Recommended expansion order:

1. Broader MPI coverage, if the next workflow needs custom communicators,
   additional collectives, or more boundary synchronization helpers
2. 1D and 2D builds, because dimensional coverage expands the same API design
   without introducing major new subsystems

GPU, particles, and broader `AmrCore` functionality should still follow after
the CPU ownership and iteration model has been exercised through those smaller
expansion steps.

## References

- Mojo FFI documentation: <https://docs.modular.com/mojo/std/ffi/>
- Mojo value creation: <https://docs.modular.com/mojo/manual/lifecycle/life/>
- Mojo value destruction: <https://docs.modular.com/mojo/manual/lifecycle/death/>
- Mojo lifetimes and origins:
  <https://docs.modular.com/mojo/manual/values/lifetimes/>
- `pyamrex` entry point: `../pyamrex/src/pyAMReX.cpp`
- `pyamrex` public API guide: `../pyamrex/docs/source/usage/api.rst`
- AMReX Fortran-interface C++ wrappers:
  - `../amrex/Src/F_Interfaces/Base/AMReX_init_fi.cpp`
  - `../amrex/Src/F_Interfaces/Base/AMReX_boxarray_fi.cpp`
  - `../amrex/Src/F_Interfaces/Base/AMReX_distromap_fi.cpp`
  - `../amrex/Src/F_Interfaces/Base/AMReX_geometry_fi.cpp`
  - `../amrex/Src/F_Interfaces/Base/AMReX_multifab_fi.cpp`
