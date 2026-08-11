# pyAMReX 3D Feature-Parity Inventory

Last updated: 2026-08-11

## Purpose

This document tracks the work required for `mojo-amrex` to reach practical
feature parity with the three-dimensional pyAMReX bindings.

The comparison baseline is the public `amrex.space3d` API on pyAMReX's
`development` branch at commit
`9299a05b4baef9955ce7a4a8346e7727f594cccc` (2026-08-05). The baseline should
be refreshed before planning or declaring a parity milestone complete.

Parity means that a Mojo application can perform the same AMReX workflows. It
does not require reproducing Python-specific spelling, dynamic indexing, or
every generated template-specialization name. Parametric Mojo types and
Mojo-native kernels are preferred where they provide the same capability with
stronger compile-time typing.

## Scope

In scope:

- three-dimensional AMReX only
- serial and MPI execution
- CPU execution and the GPU backends supported by Mojo and this project
- core index-space and geometry types
- field data, iteration, arithmetic, communication, and synchronization
- physical boundary conditions
- parameter parsing
- field and particle I/O
- adaptive-mesh-refinement hierarchy management
- mesh particles
- zero-copy data access and relevant interoperability
- MPMD and supporting utilities exposed by pyAMReX

Explicitly out of scope:

- one-dimensional and two-dimensional bindings
- embedded-boundary APIs and `AMReX_EB`
- OpenMP support and `AMReX_OMP`
- APIs not exposed by pyAMReX, such as a general binding surface for AMReX
  linear solvers or FFTs
- literal reproduction of Python-only conveniences such as NumPy slice syntax
  when an idiomatic Mojo API provides equivalent behavior
- legacy AoS+SoA particle layouts
- application-specific precompiled particle-container names; applications map
  their component metadata to the common runtime-schema container instead

## Status Legend

| Status | Meaning |
|---|---|
| Complete | The relevant workflow is available and has focused tests. |
| Partial | A useful subset exists, but material pyAMReX workflows are missing. |
| Missing | No public equivalent currently exists. |
| Mojo equivalent | The capability exists through a deliberately different, idiomatic Mojo API. |
| Out of scope | The capability is intentionally excluded from this parity target. |

## Summary

| Area | Status | Main gap |
|---|---|---|
| Runtime lifecycle | Partial | Configuration, arenas, transfers, and MPMD lifecycle |
| ParallelDescriptor | Partial | Only rank/count/IO-processor queries exist |
| GPU runtime | Partial | Allocators, transfers, events, and portable interoperability |
| Core value types | Partial | Rich `IntVect`, `Box`, `IndexType`, and vector operations |
| BoxArray and distribution | Partial | Refinement, coarsening, definition, processor maps, queries |
| Geometry | Partial | Coordinate systems, refinement, periodic-domain helpers |
| Array4 and tile views | Mojo equivalent | More dtypes and external interchange remain |
| MultiFab | Partial | Full algebra, metadata, synchronization, and global operations |
| Integer and lower-level FABs | Missing | `iMultiFab`, `FArrayBox`, `BaseFab`, and generic `FabArray` |
| Boundary conditions | Missing | `BCRec`, boundary enums, domain fills, user callbacks |
| ParmParse | Partial | Strings, booleans, arrays, files, removal, table inspection |
| Field I/O | Partial | Multilevel output, `VisMF`, `PlotFileData`, and readback |
| AMR hierarchy | Missing | `AmrMesh`, `AmrCore`, tagging, regridding, callbacks |
| Particles | Missing | Containers, schemas, tiles, redistribution, and restart |
| Utility containers | Missing | POD vectors, AMReX vectors, arenas, small matrices |
| MPMD | Missing | Initialization, rank topology, and `MPMD_Copier` |

## Detailed Inventory

### 1. Runtime, Configuration, and Parallel Runtime

pyAMReX baseline:

- `initialize`, `finalize`, `initialized`, and the `AMReX` runtime stack
- `Config` queries for dimension, precision, MPI, and GPU configuration
- `ParallelDescriptor.IOProcessor`, `IOProcessorNumber`, `MyProc`, and `NProcs`
- arena accessors and memory-property queries
- host-to-device and device-to-host copies
- MPMD initialization, topology queries, finalization, and `MPMD_Copier`

Current `mojo-amrex`:

- `AmrexRuntime` owns initialization, finalization, the shared library, and
  dependent-object leases
- runtime creation accepts arguments and `use_parmparse`
- MPI rank/count/IO-processor queries are available
- CUDA/HIP backend, device, stream selection, and synchronization queries are
  available

Missing for parity:

- a public immutable build/runtime configuration object
- arena handles and `is_host_accessible`, `is_device_accessible`, `is_managed`,
  and `is_pinned` queries independent of a `MultiFab`
- explicit synchronous and asynchronous host/device copy primitives
- richer `ParallelDescriptor` operations exposed by the pyAMReX target
- MPMD lifecycle and `MPMD_Copier`
- a documented behavior matrix for CPU, CUDA, HIP, MPI, and MPI+GPU builds

Acceptance criteria:

- a program can inspect all supported compile-time AMReX options at runtime
- rank-local and IO-processor behavior is covered in serial and two-rank tests
- supported memory spaces can be selected and queried without unsafe casts
- MPMD send/receive behavior has a multi-program regression test

### 2. Core Value and Index-Space Types

pyAMReX baseline:

- `Dim3`, `IntVect3D`, `RealVect`, `IndexType`, `Direction`, and `Periodicity`
- `Box` construction, iteration, arithmetic, containment, intersection,
  shifting, growing, refinement/coarsening, centering conversion, and queries
- free helpers including `coarsen`, `refine`, `lbound`, `ubound`, `length`,
  `min`, and `max`

Current `mojo-amrex`:

- C-ABI-safe `IntVect3D`, `RealVect3D`, `Box3D`, and `RealBox3D` values
- box construction, cell count, cell iteration, and centering metadata
- these values are device-passable where appropriate

Missing for parity:

- vector indexing, iteration, arithmetic, comparisons, reductions, and
  unit/cell/node vector constructors
- first-class `IndexType`, `Direction`, and `Periodicity`
- most `Box` mutation/query operations
- free refinement, coarsening, bounds, and length helpers
- consistent `Writable`, equality, and copy behavior across all value types

Acceptance criteria:

- the non-EB cases in pyAMReX's `test_intvect.py`, `test_box.py`,
  `test_indextype.py`, `test_periodicity.py`, `test_realvect.py`, and
  `test_realbox.py` have Mojo-equivalent tests
- all value operations that are meaningful in kernels compile for the device

### 3. BoxArray, DistributionMapping, and Geometry

pyAMReX baseline:

- `BoxArray` construction, definition, indexing, resizing, refinement,
  coarsening, centering conversion, capacity/emptiness, minimal-box queries,
  and maximum-size decomposition
- `DistributionMapping` construction, definition, processor-map access, size,
  capacity, and link-count queries
- `CoordSys`, `Geometry`, and `GeometryData`, including physical bounds,
  periodicity, cell sizes, refinement/coarsening, and periodic-domain helpers

Current `mojo-amrex`:

- `BoxArray` construction from one box, indexing, size, maximum-size
  decomposition, and centering conversion
- `DistributionMapping` construction from a `BoxArray`
- `Geometry` construction and domain, physical-domain, cell-size, and
  periodicity queries

Missing for parity:

- `BoxArray` refinement, coarsening, resize/clear/define, emptiness, capacity,
  minimal-box, and equality/coarsenability queries
- `DistributionMapping` indexing and processor-map introspection
- coordinate-system selection and queries
- geometry refinement/coarsening, redefinition, periodic lengths/shifts, and
  inside/outside-domain tests
- non-owning `GeometryData` suitable for kernels and callbacks

Acceptance criteria:

- grid layouts can be created, transformed, distributed, and inspected without
  dropping to the C ABI
- cell-, face-, edge-, and node-centered layouts have focused tests
- periodic geometry helpers are tested in serial and MPI configurations

### 4. Array4, FAB, and Zero-Copy Views

pyAMReX baseline:

- mutable and const `Array4` bindings for floating-point, integer, unsigned,
  complex, and selected extended scalar types
- `BaseFab`, `FArrayBox`, generic `FabArray`, and their metadata/factory types
- zero-copy CPU and GPU array exposure to NumPy, CuPy, Numba, Torch, dpnp, and
  other DLPack/array-interface consumers

Current `mojo-amrex`:

- origin-aware mutable `Array4View` and `TileView` for `Float32` and `Float64`
- direct indexed access and host/device tile kernels
- explicit AMReX-stream wrapping for CUDA/HIP execution

Classification:

- the core zero-copy compute workflow is a **Mojo equivalent**, not a missing
  Python API
- dtype breadth, const views, lower-level FAB ownership, and external
  interchange remain incomplete

Missing for parity:

- const/read-only view types
- integer and any required complex `Array4` types
- owning `BaseFab`, `FArrayBox`, and generic `FabArray` wrappers
- allocator/factory metadata
- safe view invalidation rules for resize, clear, regrid, and redistribution
- DLPack export/import if cross-framework zero-copy interchange is included in
  the release target

Acceptance criteria:

- host and device views are verified to alias AMReX storage without copies
- mutable and const access are distinguished by the Mojo type system
- every supported dtype has bounds, stride, component, and kernel tests
- all view-producing APIs document their owner and synchronization rules

### 5. MultiFab and MFIter

pyAMReX baseline:

- `MultiFab` and `iMultiFab`
- full metadata access, iteration, component/global indexing, and conversion to
  external array views
- scalar and field arithmetic, copy, add/subtract/multiply/divide, inversion,
  linear combinations, SAXPY/XPAY, dot products, and products
- min/max/sum/norm reductions, including unique-cell behavior and index queries
- NaN/Inf detection
- average, weighted, and override synchronization
- `MFInfo`, `MFItInfo`, and the full set of valid/tile/fab/grown/nodal boxes

Current `mojo-amrex`:

- parametric floating-point `MultiFab`
- allocation, component/ghost metadata, set-value, scalar plus/multiply, copy,
  parallel copy, fill boundary, min/max/sum/norm reductions, and single-level
  plotfile output
- `MFIter`, `MFIterRange`, tile metadata, `Array4View`, and CPU/GPU
  `ParallelFor`

Missing for parity:

- `iMultiFab`
- `MFInfo`, `MFItInfo`, tiling controls, nodal tile boxes, and iterator length
- field-field arithmetic and the remaining linear algebra operations
- unique reductions, reduction index results, local/global reduction selection,
  NaN/Inf checks, and synchronization operations
- `box_array`, distribution-map, centering, shape, and factory queries
- robust component views and an idiomatic equivalent to pyAMReX global slicing

Acceptance criteria:

- every non-EB operation in pyAMReX's `test_multifab.py` and
  `test_imultifab.py` is either implemented or recorded as an intentional
  Mojo-shaped alternative
- reductions are tested on multiple boxes and multiple MPI ranks
- CPU and GPU results agree for every supported arithmetic operation
- iterator/view lifetime tests cover moves, early destruction, and exhaustion

### 6. Physical Boundary Conditions

pyAMReX baseline:

- `BCType`, `PhysBCType`, `BCRec`, and vectors of boundary records
- `fill_domain_boundary`
- no-op, CPU functor, and user-callback physical boundary functors

Current `mojo-amrex`:

- periodic/inter-box ghost exchange through `MultiFab.fill_boundary`
- no physical-domain boundary record or callback API

Missing for parity:

- boundary enums and per-component low/high records
- standard extrapolation and reflection fills
- external Dirichlet support
- a C callback table/trampoline for Mojo boundary functions
- callback error propagation and callback-scoped borrow rules

Acceptance criteria:

- periodic, extrapolation, reflection, and external-Dirichlet cases are tested
- physical boundary callbacks can safely borrow a destination `MultiFab`
- callback failures become Mojo errors rather than crossing the C ABI

### 7. ParmParse

pyAMReX baseline:

- integer, real, string, and boolean values
- arrays, input files, removal, required gets, optional queries, pretty-printing,
  and dictionary conversion

Current `mojo-amrex`:

- integer add/query and real query through typed wrapper values

Missing for parity:

- boolean and string support
- arrays of supported scalar/string types
- file loading, removal, required getters, and table inspection
- enumeration of keys and values

Acceptance criteria:

- a representative AMReX input file round-trips through typed queries
- missing, malformed, repeated, prefixed, and array-valued parameters have
  deterministic diagnostics

### 8. Field I/O and Plotfile Reading

pyAMReX baseline:

- single- and multilevel plotfile output
- `VisMF`
- `PlotFileData` field readback and level/variable/geometry metadata

Current `mojo-amrex`:

- single-level plotfile output from `MultiFab`

Missing for parity:

- multilevel plotfile output
- `VisMF` read/write
- `PlotFileData`
- discovery of variables and refinement levels
- field loading into owned `MultiFab` objects
- explicit serial-versus-collective MPI semantics

Acceptance criteria:

- single- and multilevel round-trip tests compare metadata and cell values
- plotfiles written by AMReX C++ and pyAMReX can be read by `mojo-amrex`
- output/readback is covered in serial and MPI configurations

### 9. AMR Hierarchy

pyAMReX baseline:

- `AmrInfo`, `AmrMesh`, `AmrCore`, `TagBox`, and `TagBoxArray`
- level geometry, refinement ratios, finest/max-level queries, initialization,
  tagging, and regridding
- application callbacks for creating, remaking, clearing, and tagging levels
- particle metadata through `AmrParGDB`

Current `mojo-amrex`:

- no AMR hierarchy API

Required design work:

- opaque C ABI handles for hierarchy and tag arrays
- a callback vtable containing C-compatible function pointers and user context
- C++ trampolines for each `AmrCore` callback
- status/error translation that never lets an exception cross the C ABI
- callback-scoped, non-escaping borrows for `BoxArray`,
  `DistributionMapping`, and `TagBoxArray`
- a hierarchy-owned level-data model with explicit behavior across regrids

Acceptance criteria:

- a two-level example initializes from scratch, tags cells, regrids, remakes a
  level, and clears a level
- callback order and arguments match an equivalent pyAMReX test
- stale level and tag-array views are rejected after the owning transition
- the example runs in serial, MPI, and each supported GPU configuration

### 10. Particles

pyAMReX baseline:

- legacy AoS+SoA and PureSoA particle layouts in the current public API
- particle values, arrays, tiles, tile-data views, mutable/const iterators, and
  particle containers
- compile-time and runtime real/integer components
- default, arena, pinned, and polymorphic allocator variants
- initialization, insertion, removal, counting, resizing, redistribution,
  sorting, and AMR-level operations
- plotfile/checkpoint writing, restart, and plotfile/checkpoint reading
- zero-copy host/GPU views and DataFrame conversion

Current `mojo-amrex`:

- AMReX particle support is disabled at configure time
- no particle C ABI or public Mojo types exist

Recommended Mojo shape:

- follow the direction in
  [pyAMReX issue #460](https://github.com/AMReX-Codes/pyamrex/issues/460):
  PureSoA, polymorphic allocation, and one runtime-component-only particle type
- begin with one schema-aware runtime-only PureSoA container rather than
  reproducing generated pyAMReX specialization names
- make position, ID, CPU/rank, runtime real components, and runtime integer
  components explicit in a `ParticleSchema`
- use parametric tile views where component types are known and named runtime
  lookup where they are not
- treat legacy AoS+SoA APIs as an upstream migration source, not a parity target
- handle legacy file compatibility in the I/O adapter without exposing a
  legacy in-memory public API

Missing for parity:

- particle-enabled AMReX build configuration
- schema/container/tile/iterator C ABI
- AMR metadata integration
- allocator and memory-space selection
- initialization, mutation, redistribution, sorting, and counting
- plotfile/checkpoint/restart and readback
- view invalidation and synchronization rules

Acceptance criteria:

- a PureSoA container supports named real/integer components and zero-copy tile
  iteration on CPU and supported GPUs
- serial and MPI redistribution preserve particle values and global counts
- checkpoint and plotfile round trips preserve schemas, IDs, positions,
  components, hierarchy, and next-ID state
- moves, resize, redistribution, regrid, and restart have explicit stale-view
  tests

### 11. Utility Containers, Arenas, and Algorithms

pyAMReX baseline:

- AMReX vectors for common bound types
- `PODVector` for integer, real, and `uint64` data across several allocators
- small matrices for selected dimensions and floating-point types
- arena accessors, packing helpers, validity helpers, concatenation, and
  approximate comparison

Current `mojo-amrex`:

- Mojo standard containers are used internally
- no public AMReX vector, POD-vector, arena, or small-matrix wrappers exist

Parity rule:

- do not bind an AMReX container merely because pyAMReX exposes it
- mark it as a **Mojo equivalent** when a Mojo standard type supports the same
  ownership, memory space, zero-copy boundary, and downstream AMReX calls
- add an AMReX-backed wrapper when allocator identity, device accessibility, or
  ABI exchange makes the native container semantically necessary

Acceptance criteria:

- each omitted pyAMReX utility has a recorded Mojo equivalent or an explicit
  justification
- allocator-sensitive containers preserve their AMReX allocation properties
- small-matrix operations needed by bound APIs work in host and device code

## Cross-Cutting Requirements

### C ABI Organization

The current narrow C ABI remains the correct boundary, but parity should not be
implemented as one ever-growing header and one unstructured symbol namespace.

Required changes:

- split declarations and implementations by Base, Boundary, I/O, AmrCore, and
  Particle subsystem while retaining one ABI version
- use consistent create/destroy/clone/query naming and status conventions
- distinguish owning handles, borrowed handles, callback-scoped handles, and
  POD views in the type names
- add capability/configuration queries for optional compiled subsystems
- consider schema-driven generation for repetitive dtype and particle exports
- keep ABI compatibility tests for symbol presence and POD layout

### Ownership and Invalidation

Every public handle or view must specify:

- its owner
- whether it is mutable or const
- whether it may escape the current callback or iterator step
- which operations invalidate it
- which stream/event makes its data ready
- whether destruction or finalization can fail

The existing runtime-lease and origin-aware view patterns should remain the
default. Raw pointers must not become the user-facing parity mechanism.

### Error Handling

- C++ exceptions must be caught inside the C ABI
- fallible C calls return status codes and preserve an actionable error message
- Mojo destructors remain infallible
- callbacks translate Mojo errors to C status without unwinding across C++
- collective MPI failures must not leave other ranks blocked indefinitely

### Testing

Add subsystem-oriented C ABI and Mojo suites rather than continuing to grow the
current monolithic tests. The minimum matrix is:

| Configuration | Required coverage |
|---|---|
| CPU serial | Every supported API |
| CPU MPI | Communication, reductions, I/O, AMR, and particles |
| CUDA or HIP | Views, kernels, memory spaces, synchronization, and particles |
| MPI plus GPU | Ghost exchange, reductions, I/O, AMR, and redistribution |

For each inventory section, port the behavior of the corresponding pyAMReX
tests without copying Python-specific implementation details. Round-trip tests
must compare metadata and underlying values, not only successful completion.

## Delivery Roadmap

### Milestone 1: Complete the Base Field Layer

- finish value/index types, grid metadata, and geometry
- add `iMultiFab`, lower-level FABs, full `MultiFab` algebra, and iterator options
- complete `ParmParse`
- establish the subsystem-oriented test layout

Exit condition: all non-EB, non-I/O Base field tests are implemented or have a
documented Mojo equivalent.

### Milestone 2: Boundaries and Field I/O

- add boundary records, standard fills, and user callbacks
- add multilevel plotfile output, `VisMF`, `PlotFileData`, and readback

Exit condition: a multilevel field can be filled at physical boundaries,
written, read back, and compared in serial and MPI runs.

### Milestone 3: AMR Hierarchy

- implement tagging, hierarchy metadata, callbacks, and regridding
- add a two-level runnable example and lifecycle regressions

Exit condition: a Mojo-owned `AmrCore` workflow matches the level transitions
and grid metadata of the equivalent pyAMReX workflow.

### Milestone 4: PureSoA Particles

- enable AMReX particles
- implement schema-aware containers, tiles, iterators, redistribution, and I/O
- integrate particles with the AMR hierarchy

Exit condition: particle creation, compute, redistribution, regrid, checkpoint,
and restart pass in serial, MPI, GPU, and MPI+GPU configurations where those
backends are available.

### Milestone 5: Interoperability and Long-Tail Utilities

- add DLPack if required by the parity release
- add MPMD and allocator-sensitive utility containers
- classify remaining generated pyAMReX specializations as implemented,
  Mojo-equivalent, intentionally unsupported, or downstream-specific

Exit condition: every in-scope public pyAMReX capability has a disposition in
this inventory and all claimed parity workflows have focused tests.

## Definition of Done

The non-EB 3D parity target is complete when:

1. Every in-scope pyAMReX public class and free function has an implementation,
   a tested Mojo-equivalent workflow, or an explicit unsupported disposition.
2. The Base, Boundary, I/O, AmrCore, and Particle acceptance criteria above pass.
3. Serial and MPI suites pass on CPU.
4. Relevant suites pass on each GPU backend supported by Mojo and this project.
5. Ownership, invalidation, error, and synchronization behavior is documented
   for every owning type and non-owning view.
6. The comparison baseline has been refreshed against the then-current
   pyAMReX `development` branch.

## Reference Sources

- [pyAMReX Python API](https://pyamrex.readthedocs.io/en/latest/usage/api.html)
- [pyAMReX compute and zero-copy examples](https://pyamrex.readthedocs.io/en/latest/usage/compute.html)
- [pyAMReX source repository](https://github.com/AMReX-Codes/pyamrex)
- [`mojo-amrex` bindings plan](mojo-amrex-bindings-plan.md)
- [`mojo-amrex` implementation notes](implementation.md)
- [`mojo-amrex` GPU interop audit](gpu-synchronization-audit.md)
