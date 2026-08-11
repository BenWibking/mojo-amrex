# Roadmap to pyAMReX 3D Feature Parity

Last updated: 2026-08-11

## Goal

Bring `mojo-amrex` to practical feature parity with the public three-dimensional
pyAMReX bindings while preserving an idiomatic, ownership-safe Mojo API.

The detailed capability list and current status live in
[pyamrex-3d-parity-inventory.md](pyamrex-3d-parity-inventory.md). This roadmap
turns that inventory into dependency-ordered implementation phases.

Parity is defined by supported workflows and observable behavior, not by
literal reproduction of Python names or every generated pyAMReX template
specialization. Parametric Mojo APIs should replace repeated dtype, allocator,
matrix, and particle-specialization names where they provide equivalent
capability.

## Scope

In scope:

- three-dimensional AMReX
- serial and MPI execution
- CPU and the GPU backends supported by Mojo and this repository
- Base mesh, geometry, field, iterator, and communication APIs
- physical boundary conditions
- parameter parsing
- field and particle I/O
- AMR hierarchy management
- mesh particles
- zero-copy access, synchronization, and relevant data interchange
- MPMD and supporting utilities exposed by pyAMReX

Out of scope:

- one-dimensional and two-dimensional bindings
- embedded boundaries and `AMReX_EB`
- OpenMP and `AMReX_OMP`
- general AMReX subsystems not exposed by pyAMReX, such as linear solvers and
  FFTs
- Python-only syntax when a tested Mojo-native equivalent provides the same
  workflow
- legacy AoS+SoA particle layouts and application-specific precompiled particle
  container types

## Planning Conventions

Each phase has four required work streams:

1. **C ABI:** AMReX-facing handles, POD values, callbacks, status handling, and
   ABI tests.
2. **Mojo API:** ownership-safe public types, methods, iteration, and errors.
3. **Validation:** focused C++ and Mojo regressions across the applicable build
   matrix.
4. **Documentation:** public API usage, ownership, invalidation, and backend
   behavior.

Relative sizes are planning aids, not calendar estimates:

| Size | Interpretation |
|---|---|
| S | Narrow extension of an established pattern |
| M | One subsystem with several types and focused integration work |
| L | Broad subsystem or significant cross-layer design |
| XL | New lifecycle model, callbacks, or distributed persistent data |

No phase is complete until its exit gate passes. A wrapper that compiles but
lacks ownership, MPI, or relevant GPU validation is not complete.

## Dependency Map

```text
Phase 0: parity contract and test architecture
    |
    v
Phase 1: ABI and runtime foundations
    |
    v
Phase 2: value types, grids, and geometry
    |
    v
Phase 3: complete field-data layer
    |                 \
    v                  v
Phase 4: boundaries   Phase 5: field I/O
    |                  /
    +--------+---------+
             v
Phase 6: AMR hierarchy and callbacks
             |
             v
Phase 7: particles and particle I/O
             |
             v
Phase 8: MPMD, interchange, and long-tail parity
             |
             v
Phase 9: parity audit and release hardening
```

Phases 4 and 5 may proceed in parallel once Phase 3 is stable. Parts of Phase
8, such as DLPack and MPMD, may also start earlier after their foundational
types are available, but they do not close before the main hierarchy and
particle workflows are validated.

## Phase 0: Freeze the Parity Contract and Test Architecture

Size: S

### Objective

Turn the parity inventory into a maintainable contract and create test seams
that can scale beyond the current MVP.

### Deliverables

- record the exact pyAMReX baseline commit in the inventory and test metadata
- extract a machine-readable list of in-scope pyAMReX classes, methods, and free
  functions
- assign every item one of:
  - implemented
  - partial
  - Mojo equivalent
  - planned
  - unsupported with rationale
  - out of scope
- define naming rules for Mojo equivalents
- split future tests by subsystem instead of extending the existing monolithic
  runtime/MultiFab files
- establish reusable serial, MPI, GPU, and MPI+GPU fixtures
- add a compatibility report that detects newly added upstream pyAMReX APIs
  without automatically treating them as required

### Test Layout Target

```text
tests/capi/
  base/
  boundary/
  io/
  amrcore/
  particle/
  mpmd/

tests/mojo/
  base/
  boundary/
  io/
  amrcore/
  particle/
  mpmd/
```

The migration may be incremental; existing tests remain authoritative until
their cases have moved.

### Exit Gate

- every item in the parity inventory has a stable identifier and disposition
- CI or a local task can report inventory drift against a refreshed pyAMReX
  API snapshot
- a documented pattern exists for adding one C ABI function, one Mojo wrapper,
  and its focused tests
- existing `pixi run test` and `pixi run test-mpi` behavior remains intact

## Phase 1: Establish Scalable ABI and Runtime Foundations

Size: L

### Objective

Prepare the C ABI, configuration model, and ownership conventions for AMR,
particles, callbacks, and multiple memory spaces before adding their public
APIs.

### C ABI Work

- split the public declarations and implementations into Base, Boundary, I/O,
  AmrCore, Particle, and MPMD modules while preserving one ABI version
- define consistent conventions for:
  - owning handles
  - borrowed handles
  - callback-scoped handles
  - mutable and const POD views
  - create, clone, destroy, query, and mutation functions
- retain one status/error mechanism and prevent all C++ exceptions from crossing
  the ABI
- add compiled-capability queries for MPI, GPU backend, precision, particles,
  and optional interchange support
- add ABI layout assertions for all exported POD structures
- add a symbol-presence test for the installed shared library

### Mojo API Work

- introduce a public immutable configuration value
- standardize moved-from checks and runtime leases across all owner wrappers
- define reusable const and mutable borrowed-handle patterns
- define an invalidation-token or generation pattern for storage that can move
  during resize, regrid, or particle redistribution
- define the callback error channel before implementing user callbacks
- document supported CPU/GPU/MPI combinations

### Runtime Capabilities

- expose build dimension, precision, MPI state, GPU backend, and particle state
- expose arena/memory-space properties needed by later field and particle APIs
- add explicit host-to-device and device-to-host copy operations
- define synchronous and asynchronous copy semantics
- retain direct CUDA/HIP stream wrapping and make synchronization requirements
  part of the public contract

### Exit Gate

- the ABI is organized for independent subsystem growth
- configuration queries agree with the linked AMReX build
- owning, borrowed, callback-scoped, const, and mutable handle patterns each
  have a focused lifecycle test
- no destructor can report or propagate an error
- CPU, MPI, and available GPU smoke tests pass

## Phase 2: Complete Core Value Types, Grid Layouts, and Geometry

Size: L

### Objective

Provide the complete non-EB index-space and geometry vocabulary required by
field, boundary, AMR, and particle APIs.

### Value Types

- complete `IntVect3D` indexing, iteration, arithmetic, comparisons, component
  min/max, sum, and standard constructors
- complete `RealVect3D` arithmetic, indexing, comparisons, and conversions
- add first-class `IndexType`, `Direction`, and `Periodicity`
- complete `Box3D`:
  - containment and intersection
  - grow, grow-low, and grow-high
  - shift and slab construction
  - refinement and coarsening
  - enclosed-cell and surrounding-node conversions
  - size, length, volume, emptiness, validity, and centering queries
  - iteration over cells
- add free bounds, length, refine, coarsen, min, and max helpers where they
  improve parity or kernel ergonomics
- keep kernel-relevant values device-passable

### BoxArray and DistributionMapping

- add define, clear, resize, empty, capacity, and indexing operations
- add refine, coarsen, coarsenability, centering, equality, and minimal-box
  operations
- expose distribution size, indexing, processor maps, and link-count metadata
- preserve runtime leases through all copied or transformed layouts

### Geometry

- add coordinate-system support
- add geometry define, refine, and coarsen operations
- add periodic length/shift and domain-growth helpers
- add inside/outside physical-domain checks
- add a non-owning, device-usable geometry-data view

### Validation

- port the behavior of pyAMReX's non-EB tests for `IntVect`, `RealVect`, `Box`,
  `IndexType`, `Periodicity`, `BoxArray`, `DistributionMapping`, and `Geometry`
- test cell-, face-, edge-, and node-centered layouts
- test periodic geometry in serial and MPI runs
- compile kernel-relevant value operations for each supported GPU backend

### Exit Gate

- later phases can express all grid, centering, periodicity, and geometry inputs
  without adding ad hoc POD types
- transformed layouts retain correct ownership and runtime state
- all relevant Base geometry tests pass on CPU, MPI, and supported GPUs

## Phase 3: Complete the Field-Data Layer

Size: XL

### Objective

Reach practical parity for `Array4`, FAB, `MultiFab`, integer fields, iteration,
communication, arithmetic, reductions, and memory spaces.

### Data Types and Ownership

- add read-only `Array4View` and `TileView` variants
- add integer views and `iMultiFab`
- decide which additional pyAMReX scalar types are required for workflow parity
- add owning `BaseFab` and `FArrayBox` wrappers
- add generic `FabArray` metadata/factory wrappers only where downstream APIs
  require them
- expose arena selection and allocation properties
- enforce view invalidation after clear, resize, redefinition, and owner death

### MultiFab Metadata and Iteration

- expose box array, distribution map, centering, shapes, components, ghosts,
  memory arena, and factory metadata
- add `MFInfo` and `MFItInfo` equivalents
- add iterator tiling controls, length, nodal tile boxes, and all grown-box forms
- retain direct CPU/GPU `ParallelFor` as the primary Mojo compute path
- define an idiomatic alternative to pyAMReX global slice reads/writes

### Arithmetic and Reductions

- add field add, subtract, multiply, and divide
- add inversion, negate, copy/swap, add-product, linear combination, SAXPY, and
  XPAY operations
- add dot products and any weighted operations exposed by pyAMReX
- add local/global and unique-cell reduction modes
- add reduction index results
- add NaN and Inf detection
- add average, weighted, and override synchronization
- complete component and ghost-region validation for every operation

### Communication and Memory Movement

- complete parallel copy variants and periodicity inputs
- cover fill-boundary component and ghost-vector variants
- add explicit host/device copies using pinned or managed staging where needed
- test behavior on non-host-accessible storage

### Validation

- differential tests compare Mojo and pyAMReX results from identical small
  layouts and deterministic input values
- reductions cover multiple boxes and MPI ranks
- CPU and GPU arithmetic results agree within dtype-appropriate tolerances
- tests cover centering, ghosts, component subranges, aliasing, and invalid
  arguments
- lifecycle tests cover moves, early destruction, iterator exhaustion, and
  stale views

### Exit Gate

- every in-scope non-EB behavior in pyAMReX's `test_array4.py`,
  `test_basefab.py`, `test_farraybox.py`, `test_multifab.py`, and
  `test_imultifab.py` is implemented or mapped to a tested Mojo equivalent
- field compute and communication pass on CPU serial, CPU MPI, supported GPUs,
  and MPI+GPU where available
- no public field operation requires direct use of raw C ABI handles

## Phase 4: Add Physical Boundary Conditions

Size: L

### Objective

Support standard physical boundary records and safe application-defined
boundary fills.

### Deliverables

- add `BCType`, `PhysBCType`, and `BCRec` equivalents
- add collections of boundary records per field component
- implement `fill_domain_boundary` for supported extrapolation and reflection
  types
- add no-op and standard CPU boundary functors
- define a C-compatible callback table for user boundary functions
- pass destination component, component count, ghost vector, time, and boundary
  component index with the same semantics as pyAMReX
- support external Dirichlet values through application callbacks
- translate callback failures into C status and then Mojo errors
- prevent callback-scoped views from escaping

### Validation

- test periodic, first-order extrapolation, reflection, and external Dirichlet
  boundaries
- cover multiple components and nonzero boundary-component offsets
- compare ghost-cell values against a C++ AMReX or pyAMReX reference
- run serial and MPI cases
- test callback failure and lifetime handling

### Exit Gate

- a field can fill inter-box, periodic, and physical-domain ghosts without raw
  ABI calls
- user callback errors cannot unwind across C++
- all boundary view lifetimes are enforced or rejected deterministically

## Phase 5: Complete Field I/O and Plotfile Readback

Size: L

### Objective

Support complete field output and restartable/readable plotfile workflows.

### Deliverables

- retain single-level plotfile writing and add missing metadata controls
- add multilevel plotfile writing
- add `VisMF` read/write capability
- add `PlotFileData`:
  - dimension and finest-level queries
  - variable names and component counts
  - time and level-step metadata
  - refinement ratios
  - physical-domain and cell-size metadata
  - box arrays and synchronized distribution maps
  - field extraction by level and variable
- define whether read fields borrow reader storage or return owned `MultiFab`
  values; prefer owned results unless zero-copy lifetime is explicit
- document collective MPI participation for every I/O call

### Validation

- round-trip one- and multilevel plotfiles
- compare metadata and cell values, not only file existence
- read plotfiles written by AMReX C++ and pyAMReX
- read Mojo-written plotfiles with pyAMReX
- run serial and MPI round trips
- verify deterministic diagnostics for missing, malformed, or incompatible data

### Exit Gate

- a multilevel field hierarchy can be written, reopened, inspected, and
  reconstructed in Mojo
- cross-reader compatibility with pyAMReX and AMReX C++ is demonstrated
- collective I/O requirements are documented and tested

## Phase 6: Implement AMR Hierarchy and Callback Support

Size: XL

### Objective

Support `AmrMesh`/`AmrCore` workflows, tagging, regridding, and safe
application-defined level callbacks.

### Hierarchy Types

- add `AmrInfo`, `AmrMesh`, `AmrCore`, `TagBox`, `TagBoxArray`, `ParGDBBase`,
  `AmrParGDB`, and required hierarchy vectors
- expose maximum/finest level, geometry per level, refinement ratios,
  distribution maps, and box arrays
- support initialization from scratch and regridding
- expose the particle metadata broker required by Phase 7

### Callback ABI

- define a versioned callback vtable with a user-context pointer
- implement C++ trampolines for:
  - make new level from scratch
  - make new level from coarse
  - remake level
  - clear level
  - error estimation/tagging
- expose callback inputs as non-owning, callback-scoped handles
- translate Mojo errors to status values without unwinding across C++
- define cleanup behavior if a callback fails partway through a collective AMR
  operation

### Mojo Ownership Model

- make hierarchy ownership of level data explicit
- define whether application level fields are registered, returned, or stored
  behind a Mojo callback context
- invalidate old level views after remake, clear, or regrid
- prevent `TagBoxArray` callback views from escaping
- document callback order and collective MPI requirements

### Validation

- build a deterministic two-level refinement example
- initialize a coarse level, tag a region, create a fine level, regrid, remake,
  and clear levels
- compare callback order, layouts, refinement ratios, and metadata against an
  equivalent pyAMReX example
- inject callback failures at each callback type
- test serial, MPI, supported GPU backends, and MPI+GPU where available

### Exit Gate

- a Mojo application can own and evolve a multilevel AMR hierarchy
- all required callbacks have safe lifetime and error behavior
- stale hierarchy and tag views fail deterministically
- the two-level example passes across the supported execution matrix

## Phase 7: Implement Particles and Particle I/O

Size: XL

### Objective

Follow the direction in
[pyAMReX issue #460](https://github.com/AMReX-Codes/pyamrex/issues/460) by
providing one runtime-component-only PureSoA particle workflow with polymorphic
allocation, AMR integration, distributed redistribution, device access, and
restart support.

### Build and ABI Foundation

- enable `AMReX_PARTICLES` independently of excluded subsystems
- define particle schema, container, tile, iterator, and tile-data handles
- expose mutable and const particle views
- add allocator/memory-space selection
- connect containers to standalone geometry/layout metadata or `AmrParGDB`

### Recommended Public Model

- `ParticleSchema` records position, ID/CPU representation, named real
  components, named integer components, and optional units/metadata
- `ParticleContainer[Schema]` presents typed Mojo access to the common
  runtime-component-only distributed particle storage
- mutable and const particle-tile iterators borrow the container
- tile views provide zero-copy named component arrays
- runtime component lookup is available when compile-time names are not known
- generated pyAMReX application-specific class names map to schemas or factory
  functions rather than separate Mojo source types

### Core Operations

- define and redefine containers
- add compile-time and runtime real/integer components
- initialize randomly, per box, and from explicit particle data
- insert, remove, clear, reserve, resize, and count particles
- iterate mutable and const tiles
- sort by cell and bin
- redistribute after particle motion or hierarchy changes
- query local, level, grid, and global counts
- integrate level creation/removal with the AMR hierarchy

### I/O and Restart

- write particle plotfiles and checkpoints
- restart from checkpoints
- read particles from plotfiles and checkpoints
- preserve schemas, names, types, IDs, ranks, positions, components, hierarchy,
  and next-ID state
- define behavior for empty levels and changed layouts

### Migration Compatibility

- do not expose a legacy AoS+SoA public API
- map current pyAMReX PureSoA specializations and application-specific
  containers to runtime `ParticleSchema` values or factories
- support legacy plotfile/checkpoint inputs through the I/O adapter when
  required, without reproducing the legacy in-memory model
- document the upstream transition boundary while issue #460 remains open

### Validation

- zero-copy CPU and GPU tile mutation tests
- serial and MPI insertion, motion, redistribution, and sorting tests
- multilevel regrid tests
- plotfile and checkpoint round trips
- restart onto equal and changed layouts where AMReX supports it
- stale-view tests after resize, redistribution, regrid, clear, and restart
- global count and next-ID validation across MPI ranks

### Exit Gate

- the documented PureSoA pyAMReX workflows have Mojo equivalents
- particle compute, redistribution, AMR integration, plotfile output, checkpoint,
  and restart pass across the supported execution matrix
- every current PureSoA or application-specific pyAMReX specialization has a
  documented runtime-schema mapping or unsupported disposition

## Phase 8: MPMD, Data Interchange, and Long-Tail Utilities

Size: L

### Objective

Close remaining capability gaps that support coupling, external computation,
and less common public pyAMReX workflows.

### MPMD

- add initialization-without-split, initialized/finalized queries, application
  number, program ID, rank, and process-count operations
- add `MPMD_Copier` definition, metadata, send, and receive
- document ownership and collective requirements across application groups
- add a multi-program integration test

### Data Interchange

- decide whether DLPack is required for the parity release
- if required, export field and particle tile views with:
  - dtype
  - shape and strides
  - device type and ID
  - ownership/deleter semantics
  - producer/consumer stream synchronization
- add import only where AMReX can safely adopt or copy the external storage
- test with available CPU and GPU DLPack consumers

### Utility Types

- classify AMReX vectors, POD vectors, arenas, small matrices, and free
  algorithms as:
  - native wrapper required
  - Mojo standard-library equivalent
  - internal implementation detail
  - unsupported with rationale
- bind allocator-sensitive containers when native memory identity matters
- add small matrices needed by public field, AMR, or particle APIs
- add packing, validity, concatenation, and approximate-comparison helpers when
  they support an in-scope workflow

### Exit Gate

- MPMD communication has a reproducible integration test
- external interchange, if included, has explicit ownership and stream tests
- every remaining utility in the inventory has a final disposition
- no required workflow depends on an undocumented raw pointer conversion

## Phase 9: Parity Audit and Release Hardening

Size: L

### Objective

Prove parity against a refreshed upstream baseline and make the expanded API
maintainable as a released binding rather than a collection of demonstrations.

### Upstream Audit

- refresh the pyAMReX `development` commit
- regenerate the public API inventory
- review added, removed, and changed upstream capabilities
- update every disposition and record deliberate differences
- run deterministic cross-implementation comparison cases

### Quality and Compatibility

- freeze and document the public C ABI versioning policy
- add backwards-compatibility checks for installed Mojo packages and shared
  libraries
- verify all optional capability combinations fail clearly when unavailable
- audit ownership, moved-from behavior, invalidation, callbacks, and collective
  failure handling
- audit GPU synchronization and non-host-accessible memory
- audit MPI operations for mismatched collective participation

### Documentation and Examples

- add one focused user guide per subsystem
- document the pyAMReX-to-Mojo mapping for renamed or parametric APIs
- provide runnable examples for:
  - single-level field compute
  - MPI ghost exchange
  - physical boundary fills
  - plotfile round trip
  - two-level AMR regridding
  - PureSoA particles with redistribution and restart
  - supported GPU execution
  - MPMD coupling

### Release Matrix

| Configuration | Required result |
|---|---|
| CPU serial | Full in-scope suite |
| CPU MPI | Full communication, I/O, AMR, particle, and MPMD suite |
| Each supported GPU backend | Field, view, callback, and particle GPU suite |
| MPI plus supported GPU | Communication, I/O, AMR, and particle suite |

OpenMP and embedded-boundary configurations are not part of this matrix.

### Exit Gate

- every in-scope public pyAMReX capability is implemented, mapped to a tested
  Mojo equivalent, or explicitly unsupported with rationale
- all subsystem acceptance gates pass
- the full supported build matrix passes from a clean bootstrap
- install-tree examples use only documented public APIs
- the inventory, roadmap, implementation notes, and user documentation agree

## Work-Package Rules

Within each phase, implementation work should be split into reviewable vertical
slices. A work package should normally include:

- one coherent user workflow
- the smallest required C ABI extension
- safe Mojo wrappers
- C ABI and Mojo tests
- ownership and backend documentation
- exact validation commands and observed platform configuration

Avoid horizontal packages such as “add all C ABI declarations” followed later
by wrappers and tests. A representative slice such as “construct `iMultiFab`,
iterate its tiles, mutate integer values, and reduce them under MPI” provides a
meaningful completion signal and exposes lifecycle errors early.

## Completion Criteria

The roadmap is complete only when all of the following hold:

1. The parity inventory has been refreshed against the then-current pyAMReX
   `development` branch.
2. Every in-scope capability has a tested implementation, tested Mojo
   equivalent, or explicit unsupported disposition.
3. Serial and MPI CPU tests pass from a clean environment.
4. Relevant tests pass on every GPU backend supported by Mojo and this project.
5. Field and particle I/O round trips preserve metadata and underlying values.
6. AMR and particle lifecycle transitions reject stale views.
7. Callback errors and C++ exceptions never unwind across the C ABI.
8. Ownership, invalidation, collective behavior, and synchronization are
   documented for every public owner and view.
9. EB, OpenMP, and other exclusions remain clearly labeled and are not required
   by the release test matrix.

## References

- [3D parity inventory](pyamrex-3d-parity-inventory.md)
- [Original bindings plan](mojo-amrex-bindings-plan.md)
- [Implementation notes](implementation.md)
- [GPU synchronization audit](gpu-synchronization-audit.md)
- [pyAMReX Python API](https://pyamrex.readthedocs.io/en/latest/usage/api.html)
- [pyAMReX compute documentation](https://pyamrex.readthedocs.io/en/latest/usage/compute.html)
- [pyAMReX source repository](https://github.com/AMReX-Codes/pyamrex)
