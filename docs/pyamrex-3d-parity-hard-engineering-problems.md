# Hard Engineering Problems for pyAMReX 3D Parity

Last updated: 2026-08-11

## Purpose

This document identifies the architecture and correctness problems that must be
solved for `mojo-amrex` to reach practical three-dimensional feature parity
with pyAMReX. It complements the
[parity inventory](pyamrex-3d-parity-inventory.md) and the
[phased roadmap](pyamrex-3d-parity-roadmap.md).

The difficult part is not the number of missing methods. Most value-type,
metadata, and `MultiFab` operations extend patterns already established in the
repository. The high-risk work begins where delayed callbacks, mutable borrowed
storage, distributed state, accelerator execution, and persistent I/O cross the
C ABI.

## Scope and Particle Direction

The scope remains:

- three-dimensional bindings only
- serial and MPI execution
- CPU and GPU backends supported by Mojo and this repository
- no embedded boundaries
- no OpenMP

Particle work follows the upstream direction in
[pyAMReX issue #460](https://github.com/AMReX-Codes/pyamrex/issues/460):

1. use PureSoA rather than legacy AoS+SoA
2. use polymorphic allocation rather than separate container types for each
   memory space
3. converge on one runtime-component-only PureSoA particle type

Issue #460 describes the runtime-only type as the future third step and remains
open. The current pyAMReX specialization surface is therefore a migration
source, not the public model to copy. `mojo-amrex` should map current
specializations to runtime `ParticleSchema` values while targeting the common
runtime-only container directly.

Legacy AoS+SoA is not part of the public parity target. Legacy file formats may
still require input adapters, but those adapters must not force the old
in-memory model into the Mojo API.

## Severity Classes

| Class | Meaning |
|---|---|
| Architecture gate | Must be proven before broad dependent implementation begins. |
| Correctness gate | A wrong design may appear to work but can corrupt data, hang ranks, or use invalid memory. |
| Scale gate | A naive implementation works initially but becomes unmaintainable at parity scale. |

The first three problems below are architecture gates. Problems four through
seven are correctness gates. Problems eight and nine are scale gates.

## 1. Calling Mojo Safely from AMReX C++

Class: Architecture gate

### Why It Is Hard

The current binding direction is mostly synchronous:

```text
Mojo -> C ABI -> AMReX C++ -> return to Mojo
```

Physical boundary conditions and `AmrCore` reverse that direction:

```text
Mojo registers application behavior
    -> AMReX stores it
        -> AMReX invokes it later from C++
            -> Mojo mutates callback-scoped AMReX data
```

The binding must support callbacks for:

- external physical boundary fills
- make-new-level-from-scratch
- make-new-level-from-coarse
- remake-level
- clear-level
- error estimation and tagging

A callback may run after the registration function has returned, may participate
in an MPI collective transition, and may receive objects that are valid only
for the duration of that invocation.

### Required Invariants

- Every function pointer has a stable C ABI signature.
- Captured Mojo state remains alive until explicit deregistration or owner
  destruction.
- The callback context cannot be moved while C++ retains its address.
- Callback arguments clearly distinguish mutable and const borrows.
- Callback-scoped handles cannot be retained for later use.
- Mojo errors become C status values; they never unwind through C++.
- C++ exceptions are caught before returning through the C ABI.
- Destroying the callback owner waits for or rules out in-flight callbacks.
- A callback failure cannot leave other MPI ranks indefinitely blocked.

### Proposed Direction

Use a versioned C callback table:

```c
struct amrex_mojo_amrcore_callbacks_v1 {
    void* context;
    status (*make_new_level_from_scratch)(void*, /* borrowed args */);
    status (*make_new_level_from_coarse)(void*, /* borrowed args */);
    status (*remake_level)(void*, /* borrowed args */);
    status (*clear_level)(void*, int level);
    status (*error_est)(void*, /* callback-scoped TagBoxArray */);
    void (*destroy_context)(void*);
};
```

The exact signatures need a prototype against the installed Mojo compiler. The
design should not assume that an arbitrary capturing Mojo closure can be passed
directly as a C function pointer. A stable trampoline with an opaque context is
the safer boundary.

Boundary and AMR callbacks should reuse one registration, ownership, error, and
in-flight-call mechanism rather than creating two independent callback systems.

### Proof Required Before Scaling

Build a standalone callback spike that:

1. allocates captured Mojo state
2. registers a function table with C++
3. invokes the callback repeatedly after registration returns
4. mutates a callback-scoped POD view
5. injects a Mojo error
6. injects a C++ exception around invocation
7. destroys the registration
8. proves no callback occurs after destruction

Only after this works should the project implement the full boundary or
`AmrCore` surfaces.

## 2. Ownership Is Not Enough: Storage Invalidation

Class: Architecture and correctness gate

### Why It Is Hard

The runtime-lease model prevents AMReX finalization while dependent owners are
alive. Mojo origins can prevent a lexical borrow from outliving its owner.
Neither mechanism alone detects this sequence:

```text
owner remains alive
    -> a view is created
        -> owner reallocates or replaces storage
            -> old view points at stale memory
```

Storage can move or change identity during:

- `BaseFab` or `MultiFab` clear/redefine operations
- owner resize
- AMR regrid, level remake, or level removal
- particle reserve/resize
- particle sorting or redistribution
- particle restart
- allocator or memory-space changes

The view may remain type-correct and non-null after it becomes semantically
invalid.

### Required Invariants

- A view never silently accesses storage from an obsolete owner state.
- Mutable and const views are distinct in the Mojo type system.
- Relocating operations cannot run while a device kernel holds a live mutable
  borrow.
- Callback-scoped handles cannot escape their callback epoch.
- Iterator-derived views cannot outlive the iterator position that produced
  them when AMReX makes that distinction relevant.
- Stale host-side views fail deterministically before dereferencing memory.
- Device-side code never pays for a host-only validity mechanism inside the hot
  index operation.

### Proposed Direction

Combine origins with a storage-generation model:

- Each relocatable owner has a stable identity and monotonically increasing
  generation.
- Each host-side view records owner identity and generation.
- Every operation that may replace storage increments the generation.
- Host access validates the captured generation before producing the raw view
  used by a loop or kernel.
- Kernel launch requires a borrow that statically prevents relocation until the
  launch has been ordered and its completion contract is satisfied.
- Callback handles use a separate callback epoch and cannot be converted into
  ordinary owning wrappers.

The generation check belongs at view acquisition and public host access, not in
every device element access.

### Proof Required Before Scaling

Add a small owner/view test type before applying the scheme everywhere. Prove
that views are rejected after move, redefine, resize, generation change, and
owner destruction, while a valid view remains device-passable and introduces no
per-element generation load in a compiled kernel.

## 3. One Runtime-Only PureSoA Particle Model

Class: Architecture gate

### Why It Is Hard

The current pyAMReX API reflects many C++ template combinations:

- compile-time particle component counts
- runtime real and integer components
- application-specific component layouts
- allocator-specific container variants
- legacy and PureSoA layouts

Copying those combinations into the Mojo C ABI would preserve existing
complexity precisely when issue #460 intends to remove it. A fully dynamic API,
however, can lose type safety, make GPU component access expensive, and obscure
checkpoint compatibility.

The binding must bridge three states:

1. current pyAMReX PureSoA specializations
2. AMReX's evolving runtime-component storage
3. one stable Mojo public API

### Required Invariants

- The public in-memory model is PureSoA only.
- One container implementation supports all application schemas.
- Allocation can select supported memory spaces without changing container
  type.
- Positions, IDs, CPU/rank data, real components, and integer components have
  explicit logical identities.
- Internal component offsets never leak into user code.
- Named component lookup is validated before a hot loop begins.
- Device kernels receive compact, validated layout metadata and raw component
  views without string lookup.
- Schema mutation is either forbidden after population or has explicit storage
  migration semantics.
- Redistribution, sorting, resize, regrid, and restart invalidate old tile
  views.

### Proposed Public Model

```text
ParticleSchema
  - position dimension and scalar type
  - ID and CPU/rank representation
  - named real components
  - named integer components
  - optional units and application metadata

ParticleContainer[Schema]
  - common runtime-component-only AMReX storage
  - polymorphic allocator selection
  - hierarchy or standalone layout metadata

ParticleLayout
  - validated component indices
  - GPU-safe metadata for hot loops

ParticleTileView[Schema]
  - zero-copy position, ID, CPU, real, and integer arrays
  - mutable or const borrow
```

`ParticleSchema` should be immutable once storage is populated. If runtime
component addition remains a parity requirement, it should either be restricted
to an empty container or implemented as an explicit schema-migration operation
that invalidates all views.

### Migration Boundary

- Current PureSoA specializations map to schema factories.
- Application-specific names do not become permanent Mojo types.
- Legacy AoS+SoA APIs are excluded.
- Legacy files may be read by translating their metadata and values into the
  runtime-only schema.
- The roadmap must track upstream issue #460 because the exact AMReX storage
  API may change while the issue remains open.

### Proof Required Before Scaling

Implement one vertical particle spike with:

- positions, ID/CPU, two named real components, and one named integer component
- polymorphic host and one supported device allocation
- const and mutable tile iteration
- one CPU and one GPU kernel
- MPI redistribution
- a checkpoint/restart round trip
- deliberate stale-view use after redistribution

Do not add multiple application schemas until this slice proves the model.

## 4. GPU Memory, Streams, and External Interchange

Class: Correctness gate

### Why It Is Hard

Zero-copy access is correct only if pointer ownership, memory accessibility, and
execution ordering are all correct. Parity introduces:

- AMReX default, host, pinned, managed, and device allocations
- field and particle views
- asynchronous host/device copies
- MPI calls involving device buffers
- AMReX streams wrapped by Mojo
- potential DLPack consumers with their own streams

A pointer with the right address, dtype, shape, and strides can still race with
its producer or outlive its allocation.

### Required Invariants

Every view and transfer must define:

- memory kind and device ID
- host and device accessibility
- producing stream
- readiness condition
- consumer-stream handoff
- completion responsibility
- earliest legal owner mutation or destruction
- behavior when no compatible GPU backend is compiled

### Proposed Direction

- Keep AMReX's active stream as the default execution stream.
- Represent synchronization as an explicit contract, not an implicit global
  device synchronization.
- Add events when ownership crosses stream domains.
- Require completion before storage-relocating owner operations.
- Use pinned staging for explicit asynchronous copies when appropriate.
- Treat DLPack as a separate interoperability layer built on proven internal
  views; do not let it define the internal ownership model.
- Implement DLPack deleter and producer/consumer stream semantics before
  advertising zero-copy interchange.

### Proof Required Before Scaling

- mutate one field and one particle tile on the AMReX stream
- hand each to a second stream with an event
- consume the result without global synchronization
- attempt owner destruction and relocation while work is outstanding
- verify correct blocking or rejection
- run under available race/synchronization diagnostics where practical

## 5. MPI Collective Failure Without Deadlock

Class: Correctness gate

### Why It Is Hard

Many parity operations are collective or lead into collective AMReX code:

- parallel copies and global reductions
- multilevel I/O
- regridding
- particle redistribution
- checkpoint/restart
- MPMD transfers

If one rank returns early after local validation or a callback failure while
other ranks enter the collective, the job can hang indefinitely. Ordinary
success tests do not exercise this failure mode.

### Required Invariants

- Purely local validation happens before entering a collective region.
- All ranks agree whether to enter or skip a collective operation.
- Callback failures become a rank-consistent failure result where recovery is
  possible.
- Resources acquired before failure are released consistently.
- No rank waits for a message or collective that another rank has abandoned.
- Unrecoverable AMReX failures use a clearly documented abort policy.

### Proposed Direction

Define one collective-call protocol:

1. perform local validation
2. reduce local validation status across the participating communicator
3. enter AMReX only when all ranks agree
4. catch local callback/C++ failures where possible
5. propagate a consistent post-operation status
6. return the same semantic error on every rank

Some AMReX internals may not permit recovery after a callback fails partway
through regrid or redistribution. Those cases need an explicit fail-stop policy
rather than an unsafe promise to recover.

### Proof Required Before Scaling

Add fault-injection hooks that fail exactly one rank:

- before a collective
- inside an application callback
- during metadata preparation for I/O
- before particle redistribution

Each test must complete with a consistent error or documented controlled abort,
never a timeout.

## 6. AMR Hierarchy State and Application Level Data

Class: Correctness gate

### Why It Is Hard

`AmrCore` does more than call user functions. It owns a state machine whose
transitions create, replace, and destroy level metadata while application code
usually owns level fields.

The binding must decide where Mojo level data lives and how callbacks exchange
it with C++:

- Does the callback return new fields?
- Does it register fields in a hierarchy-owned table?
- Does Mojo own a separate level store keyed by level and generation?
- What happens to borrowed fields during remake and clear?
- How does a particle container observe hierarchy changes?

### Required Invariants

- Each active AMR level has one authoritative geometry, box array, distribution
  map, refinement ratio, and generation.
- Level creation is atomic from the public API's perspective.
- Remake replaces the complete level state or leaves the old state intact.
- Clear invalidates all level-scoped handles.
- Regrid updates field and particle dependents in a documented order.
- A callback cannot retain temporary layout/tagging objects.
- Partial callback failure cannot leave a publicly visible half-defined level.

### Proposed Direction

Use a Mojo-owned `LevelStore` behind the callback context. Each level entry
contains owned fields and a generation tied to AMReX's current level metadata.
Callbacks mutate the store through a transaction-like interface:

```text
begin level transition
    -> construct replacement state
    -> validate layout and ownership
    -> commit replacement and increment generation
or
    -> discard replacement and retain/clear old state according to transition
```

This keeps application field ownership explicit and provides one place to
invalidate level-scoped views.

### Proof Required Before Scaling

A deterministic two-level example must exercise scratch creation, coarse-to-
fine creation, tagging, regrid, remake, clear, callback failure, and particle
metadata notification while checking callback order and generations.

## 7. I/O and Restart Are State Reconstruction Problems

Class: Correctness gate

### Why It Is Hard

Successful file creation is not parity. Restart must reconstruct compatible
distributed state, including cases where the runtime layout differs from the
writer's layout.

Field state includes:

- variable names and component order
- centering and ghost widths
- level geometry and refinement ratios
- box arrays, time, and level steps

Particle state includes:

- schema names and scalar types
- positions, IDs, CPU/rank data, and runtime components
- hierarchy association
- empty levels and empty tiles
- global next-ID state
- legacy input translation

Empty levels are especially important: optional datasets may legitimately be
absent rather than present with zero extent.

### Required Invariants

- Readback preserves logical schemas rather than only raw arrays.
- Empty levels and populations reconstruct without special-case corruption.
- MPI redistribution after reading preserves global counts and values.
- Restart on a changed box layout is either supported and tested or rejected
  explicitly.
- The global next particle ID is finalized from globally restored state.
- Legacy file translation cannot leak legacy storage indices into the public
  runtime schema.

### Proposed Direction

Separate file decoding from live-container reconstruction:

```text
file metadata + payload
    -> validated neutral restart description
        -> current runtime schema and hierarchy
            -> AMReX field/particle owners
                -> redistribution and final global-state fixup
```

This makes legacy compatibility an adapter concern and allows the live API to
remain runtime-only PureSoA.

### Proof Required Before Scaling

Maintain a cross-reader matrix:

- AMReX C++ writes, Mojo reads
- pyAMReX writes, Mojo reads
- Mojo writes, pyAMReX reads
- serial writes, MPI reads where supported
- MPI writes, different-rank-count reads where supported
- empty and nonempty levels
- equal and changed layouts

Tests compare metadata, schemas, cell values, particles, counts, and next-ID
state rather than only successful completion.

## 8. Scaling and Versioning the C ABI

Class: Scale gate

### Why It Is Hard

The current narrow ABI is understandable by inspection. Parity adds hundreds
of operations and multiple repeated dtype/view/container patterns. A naive
extension risks:

- inconsistent ownership conventions
- duplicate functions for every dtype and schema
- accidental ABI breaks
- mismatched POD layouts
- symbols present in source but absent from installed libraries
- C header and Mojo declaration drift
- optional features that fail at load time instead of reporting capability

### Required Invariants

- Public symbols follow one subsystem and lifecycle naming scheme.
- POD size, alignment, field order, and enum values are tested.
- Optional subsystems have explicit capability queries.
- Adding a symbol changes the ABI version according to a documented policy.
- Old installed Mojo packages fail clearly against incompatible libraries.
- Generated declarations are deterministic and reviewable.

### Proposed Direction

- Split source declarations by Base, Boundary, I/O, AmrCore, Particle, and MPMD
  while retaining one library-level ABI version.
- Generate repetitive dtype and particle-schema plumbing from a small manifest.
- Handwrite lifecycle-sensitive owners, callbacks, and error paths.
- Add an installed-library symbol and POD-layout conformance test.
- Keep feature availability separate from ABI compatibility.

### Proof Required Before Scaling

Generate one family of mutable/const integer and floating views end to end, then
verify deterministic output, compilation, installed symbol presence, ABI layout,
and error behavior before applying generation to more types.

## 9. Proving Parity Against a Moving and Combinatorial Target

Class: Scale gate

### Why It Is Hard

The relevant state space combines:

- CPU and supported GPUs
- serial and MPI
- host, pinned, managed, and device memory
- mutable and const views
- cell-, face-, edge-, and node-centered fields
- empty and populated data
- single-level and AMR hierarchies
- pre/post regrid and redistribution
- file-format and rank-count combinations
- an upstream pyAMReX particle API that is intentionally changing

Method-by-method unit tests cannot prove lifecycle transitions or distributed
interactions.

### Required Invariants

- Every parity claim identifies the exact upstream baseline.
- Every current upstream item has a disposition.
- Workflow tests verify metadata and underlying values.
- Environment limitations are reported separately from source regressions.
- GPU success is not inferred from CPU tests or compile-only checks.
- MPI success is not inferred from one rank.
- The runtime-only particle target is tracked separately from current
  transitional specialization names.

### Proposed Direction

Use three complementary test layers:

1. **Focused tests** for one type or operation.
2. **Differential tests** that run deterministic equivalent workflows through
   Mojo and pyAMReX.
3. **Lifecycle scenarios** that combine AMR, fields, particles, communication,
   and restart.

The decisive lifecycle scenario should:

1. create a two-level hierarchy
2. populate fields and runtime-only PureSoA particles
3. run CPU or GPU kernels
4. move particles
5. regrid and redistribute
6. fill periodic and physical boundaries
7. write a checkpoint
8. restart with a changed distribution
9. compare metadata and values globally
10. verify that all pre-transition views are stale

## What Is Mostly Implementation Volume

The following areas remain substantial but do not require new architecture once
the gates above are solved:

- `IntVect3D`, `RealVect3D`, `Box3D`, and `Periodicity` operations
- `BoxArray` and `DistributionMapping` queries and transformations
- geometry refinement and periodic helpers
- most `MultiFab` arithmetic and reductions
- `iMultiFab`
- `ParmParse` strings, booleans, arrays, and table queries
- standard non-callback boundary types
- metadata getters
- utility algorithms and small matrices

These should still be delivered as tested vertical slices, but they should not
drive the core architecture.

## Required Design Spikes

Complete these spikes before broad parity implementation:

| Order | Spike | Decisive result |
|---|---|---|
| 1 | Delayed C++-to-Mojo callback | Captured state, mutation, error injection, and destruction work safely. |
| 2 | Generation-checked borrowed view | Storage relocation makes the old view fail without adding device-loop overhead. |
| 3 | Runtime-only PureSoA particle tile | One schema works on CPU, GPU, MPI redistribution, and restart. |
| 4 | One-rank collective fault | The operation returns consistently or performs a controlled abort instead of hanging. |
| 5 | Cross-stream zero-copy handoff | Event-based handoff works without a global device synchronization. |
| 6 | Two-level transactional regrid | Level data commits or rolls back coherently and stale views are rejected. |
| 7 | Cross-language restart | Metadata and values survive AMReX/pyAMReX/Mojo writer-reader combinations. |

Failure of a spike is not merely a delayed feature. It is evidence that the
dependent roadmap phases need redesign before implementation continues.

## Decision Log Required Before Phase 3

The project should record explicit decisions for:

- callback representation and context ownership
- callback concurrency and destruction behavior
- storage identity and generation tracking
- const versus mutable borrowed-view types
- outstanding GPU-work behavior during owner mutation/destruction
- collective failure and abort policy
- runtime-only particle schema and schema-migration rules
- polymorphic allocator representation
- application level-data ownership during AMR transitions
- neutral restart-description format
- ABI generation and versioning policy
- whether DLPack is required for the parity release

These decisions should become ADRs or equivalent durable design documents once
the corresponding spikes provide evidence.

## Definition of Architectural Readiness

Broad parity implementation is architecturally ready when:

1. The callback spike proves delayed invocation, errors, and destruction.
2. The invalidation model rejects stale field, hierarchy, and particle views.
3. One runtime-only PureSoA container works across CPU, supported GPU, MPI, and
   restart.
4. Collective fault injection cannot produce an uncontrolled hang.
5. Stream ownership and cross-stream handoff are explicit and tested.
6. A two-level AMR transition commits and invalidates state correctly.
7. Cross-language restart reconstructs schemas, hierarchy, values, and global
   IDs.
8. ABI generation and conformance checks prevent declaration/layout drift.
9. The parity inventory distinguishes the current pyAMReX transition surface
   from the issue #460 runtime-only target.

## References

- [pyAMReX particle roadmap issue #460](https://github.com/AMReX-Codes/pyamrex/issues/460)
- [3D parity inventory](pyamrex-3d-parity-inventory.md)
- [3D parity roadmap](pyamrex-3d-parity-roadmap.md)
- [Original bindings plan](mojo-amrex-bindings-plan.md)
- [Runtime lifetime options](amrex-runtime-lifetime-options.md)
- [GPU synchronization audit](gpu-synchronization-audit.md)
- [Direct GPU interop design](mojo-amrex-direct-gpu-interop.md)
