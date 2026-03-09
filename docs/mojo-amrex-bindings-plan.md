# Mojo Bindings Plan for AMReX

Last updated: 2026-03-09

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
3. Mojo wrappers built on Mojo FFI

This is the right boundary because `pyamrex` is a pybind11 layer over C++, but
Mojo's FFI is designed around C ABI calls. Direct C++ binding from Mojo would
be brittle and difficult to maintain. A C shim gives us stable symbol names,
explicit ownership, and a place to flatten AMReX types into FFI-safe handles
and structs.

## Key Findings

### 1. `pyamrex` is a feature catalog, not an MVP target

`../pyamrex` exposes a large API surface:

- `pyAMReX.cpp` registers bindings across Base, AmrCore, EB, Particle, and
  utility subsystems.
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

- `initialize`
- `finalize`
- `initialized`
- `ParallelDescriptor` basics
- `IntVect`
- `Box`
- `BoxArray`
- `DistributionMapping`
- `Geometry`
- `MFIter`
- `MultiFab`
- `Array4<Real>` tile views
- minimal `ParmParse`
- plotfile write/read smoke path

This is enough to support a real AMReX workflow in Mojo:

- initialize runtime
- define domain and geometry
- create a `BoxArray`
- create a `DistributionMapping`
- allocate a `MultiFab`
- iterate tiles with `MFIter`
- access tile data through `Array4`
- do reductions or write a plotfile

### Explicit non-goals for the first milestone

- full `pyamrex` API parity
- 1D and 2D builds
- GPU array interop
- DLPack
- particles
- embedded boundary support
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

Why start with runtime loading:

- it is easier to bootstrap in a new repository
- it avoids premature toolchain friction
- it keeps library discovery explicit during early iteration

If later profiling shows call overhead matters, selected hot-path entry points
can move to compile-time `external_call`.

### Layer 3: Safe Mojo wrappers

Build user-facing Mojo types on top of the raw FFI layer:

- `IntVect3D`
- `Box3D`
- `BoxArray`
- `DistributionMapping`
- `Geometry`
- `MFIter`
- `MultiFab`
- `Array4F64View`
- `ParmParse`

Wrapper rules:

- owning Mojo types destroy the C++ object in `__del__`
- non-owning views never free memory
- iterators keep their source objects alive
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

fn main() raises:
    initialize()

    let small = IntVect3D(0, 0, 0)
    let big = IntVect3D(63, 63, 63)
    let domain = Box3D(small, big)

    var ba = BoxArray(domain)
    ba.max_size(32)

    let dm = DistributionMapping(ba)
    let geom = Geometry(domain)
    var mf = MultiFab(ba, dm, n_comp=1, n_grow=1)

    for mfi in MFIter(mf):
        var arr = mf.array(mfi)
        arr.fill(42.0)

    finalize()
```

This should be the user experience target for the first milestone.

## C API Design Notes

### Initialization

Expose simple initialization entry points:

- `amrex_mojo_initialize(argc, argv, use_parmparse)`
- `amrex_mojo_finalize()`
- `amrex_mojo_initialized()`

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

Non-owning return values must be documented clearly. For example:

- `MultiFab.box_array()` returns a borrowed handle or a copied object
- `MultiFab.array(mfi)` returns a borrowed `Array4` view valid only while the
  parent objects remain alive

It is better to copy small objects than to export tricky borrowed references
without clear lifetime guarantees.

### Array view semantics

`Array4<Real>` is the most important data path.

The first version should support:

- mutable host pointer access on CPU
- explicit shape metadata
- explicit stride metadata
- helper methods in Mojo for indexing and fill operations

The first version should not try to reproduce:

- NumPy `__array_interface__`
- CUDA `__cuda_array_interface__`
- DLPack

Those are follow-on interop features, not prerequisites for a functional Mojo
binding.

## Build System Plan

### CMake

Add a CMake build that:

- builds or finds AMReX
- compiles the C shim shared library
- installs or copies the library into a location the Mojo package can find

Recommended AMReX options for the first milestone:

- `AMReX_SPACEDIM=3`
- `AMReX_PRECISION=DOUBLE`
- `AMReX_MPI=OFF` initially, then optionally `ON`
- `AMReX_OMP=OFF` initially
- `AMReX_GPU_BACKEND=NONE`
- `AMReX_PARTICLES=OFF` initially
- `AMReX_EB=OFF` initially

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
    space3d/
      __init__.mojo
      types.mojo
      box.mojo
      boxarray.mojo
      geometry.mojo
      multifab.mojo
      mfiter.mojo
tests/
  smoke/
```

The exact top-level names can change, but separating `capi` from Mojo wrappers
is important.

## Phased Implementation Plan

### Phase 0: bootstrap

Deliverables:

- repository layout
- CMake build for shared library
- minimal Mojo package layout
- library loading via `OwnedDLHandle`
- one working smoke test

Exit criteria:

- Mojo code can load the shared library
- `initialize()` and `finalize()` succeed

### Phase 1: value types and runtime basics

Deliverables:

- `IntVect3D`
- `Box3D`
- `BoxArray`
- `DistributionMapping`
- `Geometry`
- `ParallelDescriptor` basics

Exit criteria:

- create and inspect domain objects from Mojo
- verify sizes, bounds, and box splitting behavior

### Phase 2: `MultiFab` and tile iteration

Deliverables:

- `MultiFab`
- `MFIter`
- `Array4F64View`
- core reductions: `min`, `max`, `sum`, `norm0`, `norm1`, `norm2`
- basic arithmetic: `set_val`, `plus`, `mult`, `copy`

Exit criteria:

- allocate a `MultiFab`
- iterate over tiles
- fill and modify data
- validate results against expected reductions

### Phase 3: utility and I/O

Deliverables:

- minimal `ParmParse`
- plotfile write smoke path

Exit criteria:

- configure simple values through `ParmParse`
- write a plotfile from Mojo

### Phase 4: quality and ergonomics

Deliverables:

- safer wrapper APIs
- better error messages
- docs and examples
- broader test coverage

Exit criteria:

- enough stability to use bindings in a small AMReX-driven workflow

### Phase 5: expansion

Potential additions:

- 1D and 2D builds
- MPI support
- OpenMP support
- GPU builds
- DLPack or other array interop
- particles
- EB
- more `AmrCore` functionality

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

The test strategy should verify both behavior and lifetime correctness.

## Risks and Design Traps

### 1. Trying to bind too much too early

The fastest way to stall the project is to target full `pyamrex` parity from the
start. The initial slice should be small and useful.

### 2. Borrowed lifetimes that are not explicit

`MultiFab`, `MFIter`, and `Array4` relationships are easy to get wrong. The
wrapper layer must make ownership and borrowing obvious.

### 3. Premature GPU interop

GPU support is important long-term, but it is not the right first target for a
new FFI stack. CPU correctness should come first.

### 4. Depending too heavily on AMReX's Fortran interface build path

That path is useful as a reference and may provide reusable code, but it is not
the right architectural center for a Mojo project.

### 5. Leaking C++ exceptions across the ABI

The shim must translate errors to C-compatible results. This should be enforced
from the beginning.

## Estimated Effort

Rough estimates:

- bootstrap + MVP core: 1 to 2 weeks
- solid core binding set without particles, EB, or GPU: 3 to 6 weeks
- broad `pyamrex`-like coverage: significantly more, depending on how far MPI,
  particles, and GPU interop are taken

These estimates assume reuse of AMReX and `pyamrex` behavior as design guides,
not literal code translation.

## Recommended Next Step

The next implementation step should be to create the repository skeleton and the
first C ABI header, then wire one complete vertical slice:

1. build shared library
2. load it from Mojo
3. call `initialize()`
4. construct `BoxArray`
5. construct `DistributionMapping`
6. construct `MultiFab`
7. iterate with `MFIter`
8. fill a tile through `Array4`
9. call `finalize()`

That slice will validate the overall architecture before expanding the API.

## References

- Mojo FFI documentation: <https://docs.modular.com/mojo/std/ffi/>
- `pyamrex` entry point: `../pyamrex/src/pyAMReX.cpp`
- `pyamrex` public API guide: `../pyamrex/docs/source/usage/api.rst`
- AMReX Fortran-interface C++ wrappers:
  - `../amrex/Src/F_Interfaces/Base/AMReX_init_fi.cpp`
  - `../amrex/Src/F_Interfaces/Base/AMReX_boxarray_fi.cpp`
  - `../amrex/Src/F_Interfaces/Base/AMReX_distromap_fi.cpp`
  - `../amrex/Src/F_Interfaces/Base/AMReX_geometry_fi.cpp`
  - `../amrex/Src/F_Interfaces/Base/AMReX_multifab_fi.cpp`
