# Direct GPU Interop Proposal for `mojo-amrex`

Last updated: 2026-03-12

## Goal

Define an opt-in path for launching Mojo GPU kernels directly against
AMReX-managed `MultiFab` device storage without staging tile data through Mojo
`DeviceBuffer`s.

This document is a concrete proposal for the deferred GPU path referenced in
`docs/mojo-amrex-bindings-plan.md`. It is not the current implementation.

## Current Status

Today this repository intentionally disables AMReX GPU backends. The supported
GPU path is:

1. allocate a host-backed `MultiFab`
2. borrow a host `Array4` tile view
3. copy tile data into a Mojo `DeviceBuffer`
4. launch a Mojo kernel
5. copy results back to the host tile

That staged path is correct for the current repo, but it is not direct AMReX
GPU-runtime interop.

## Investigation Summary

### What AMReX already exposes

AMReX already exposes the current GPU stream to application code:

- `amrex::Gpu::gpuStream()` returns the current backend stream handle
- on CUDA, `amrex::Gpu::Device::cudaStream()` exposes the CUDA stream directly
- `setStreamIndex`, `setStream`, and `resetStream` exist, but they operate on
  AMReX-managed streams

There are two constraints that matter for `mojo-amrex`:

- `MFIter` changes the current stream as iteration advances, so the "current
  stream" is a per-tile execution detail rather than a single process-wide
  stream
- AMReX async allocation and deferred free paths rely on `Gpu::gpuStream()`,
  so AMReX-owned device memory must be used on the AMReX-selected stream to
  preserve ordering

AMReX does not appear to support adopting an arbitrary external stream as the
current stream. Its `setStream(stream)` path resolves the handle through
AMReX's internal stream pool, which means a non-AMReX stream is not a valid
drop-in replacement.

### What Mojo stdlib already exposes

Mojo stdlib owns the low-level GPU launch path through
`std.gpu.host.DeviceContext` and `DeviceStream`.

That gives `mojo-amrex`:

- compiled kernel launch on a `DeviceStream`
- creation of Mojo-managed streams with `ctx.create_stream(...)`
- export of native stream handles from Mojo-owned streams

The missing piece is the inverse operation. I did not find a public stdlib API
that imports an external `CUstream` or `hipStream_t` into a Mojo
`DeviceStream`. Without that, direct launch onto AMReX's current stream is not
available through public Mojo APIs.

## Design Decision

AMReX must remain the owner of:

- `MultiFab` device memory
- stream selection
- async allocation and deallocation ordering

Mojo should remain responsible for:

- compiling kernels
- preparing typed launch arguments
- enqueuing work on the current AMReX stream

This means the direct path should be:

- Mojo adapts to the current AMReX stream

and not:

- AMReX adopts a Mojo-created stream

That direction matches AMReX's current ownership model and avoids breaking
ordering assumptions in `PArena`, `Elixir`, and tile-level stream scheduling.

## Proposed Architecture

### 1. Build and feature gating

Keep the current staged path as the default behavior.

Add an opt-in build path, for example:

- `AMREX_MOJO_ENABLE_GPU_INTEROP=ON`

and require:

- `AMReX_GPU_BACKEND` to be `CUDA` or `HIP`
- backend-specific tests to pass before the feature is documented as supported

The CPU-only/staged configuration should remain the default until the direct
path is validated.

### 2. Extend the C ABI for backend and stream queries

Add explicit GPU backend and stream metadata to the `mojo-amrex` C ABI.

Suggested ABI surface:

```c
typedef enum amrex_mojo_gpu_backend {
    AMREX_MOJO_GPU_BACKEND_NONE = 0,
    AMREX_MOJO_GPU_BACKEND_CUDA = 1,
    AMREX_MOJO_GPU_BACKEND_HIP  = 2
} amrex_mojo_gpu_backend_t;

typedef enum amrex_mojo_multifab_memory_kind {
    AMREX_MOJO_MULTIFAB_MEMORY_DEFAULT   = 0,
    AMREX_MOJO_MULTIFAB_MEMORY_HOST_ONLY = 1,
    AMREX_MOJO_MULTIFAB_MEMORY_DEVICE    = 2,
    AMREX_MOJO_MULTIFAB_MEMORY_MANAGED   = 3,
    AMREX_MOJO_MULTIFAB_MEMORY_PINNED    = 4,
    AMREX_MOJO_MULTIFAB_MEMORY_ASYNC     = 5
} amrex_mojo_multifab_memory_kind_t;

typedef struct amrex_mojo_gpu_stream_handle {
    int32_t backend;
    void*   handle;
    int32_t device_id;
    int32_t stream_index;
} amrex_mojo_gpu_stream_handle_t;
```

Suggested functions:

- `amrex_mojo_gpu_backend()`
- `amrex_mojo_gpu_device_id(amrex_mojo_runtime_t*, int32_t* out_device_id)`
- `amrex_mojo_gpu_current_stream(amrex_mojo_runtime_t*, amrex_mojo_gpu_stream_handle_t* out_stream)`

The stream handle struct deliberately carries both the native handle and the
AMReX stream index. The native handle is required for Mojo interop; the stream
index is useful for diagnostics and test assertions when `MFIter` rotates
streams.

### 3. Add device-only tile and `Array4` views

The current `Array4F32View`, `Array4F64View`, `TileF32View`, and `TileF64View`
types are host-indexable borrow types that also happen to be `DevicePassable`.
They should not be reused unchanged for device-only AMReX memory.

Instead add separate device-view types, for example:

- `Array4F32DeviceView`
- `Array4F64DeviceView`
- `TileF32DeviceView`
- `TileF64DeviceView`

Required properties:

- no host `__getitem__` or `__setitem__`
- still `DevicePassable`
- pointer provenance erased for device passage, as in the current staged path
- lifetime tied to the owning `MultiFab` and iterator state, just like the
  existing host tile borrows

On the C ABI side, add accessors that require `device_accessible` storage
rather than `host_accessible` storage.

### 4. Add external-stream import to Mojo stdlib

This proposal depends on a small but critical stdlib addition:

```mojo
fn import_stream(self, stream: CUstream) raises -> DeviceStream
fn import_stream(self, stream: hipStream_t) raises -> DeviceStream
```

Expected semantics:

- the returned `DeviceStream` is a non-owning wrapper around the native stream
- destroying the wrapper does not destroy the underlying AMReX stream
- the import is valid only for a matching backend and device

Without this capability, `mojo-amrex` cannot safely enqueue kernels onto the
AMReX-selected stream through public Mojo APIs.

### 5. Direct launch flow

With the pieces above in place, the direct path becomes:

1. `mojo-amrex` creates or receives an AMReX GPU-backed `MultiFab`
2. inside an `MFIter` loop, the binding borrows a device tile view
3. the binding queries the current AMReX stream handle
4. Mojo constructs or reuses a `DeviceContext` for the matching backend and device
5. Mojo imports the AMReX stream into a `DeviceStream`
6. Mojo launches the compiled kernel on that imported stream
7. control returns without an extra synchronization boundary

The key invariant is that the launch happens on the same stream AMReX is using
for that tile, so async allocation, deferred free, and tile scheduling remain
consistent.

### 6. Runtime rules

The direct path should enforce a few non-negotiable rules:

- do not launch Mojo kernels on a separately created Mojo stream when the
  kernel reads or writes AMReX-owned device memory
- do not call `ctx.synchronize()` inside tile loops
- do not reinterpret host tile views as device views
- prefer AMReX device allocation from `The_Async_Arena()` for the first direct
  path bring-up
- keep the staged helper path available as the fallback when direct GPU interop
  is not enabled

## Suggested Mojo API Shape

One reasonable wrapper-side shape is:

```mojo
from amrex.space3d import MultiFabF32, MFIter
from amrex.space3d.gpu import GpuExecutionContext

var gpu = GpuExecutionContext(runtime)
var kernel = gpu.compile(fill_kernel)

for mfi in MFIter(mf):
    let tile = mf.device_tile(mfi)
    gpu.launch_on_current_amrex_stream(
        kernel,
        tile.array_view(),
        value,
        grid_dim=...,
        block_dim=...,
    )
```

`GpuExecutionContext` would own:

- backend detection
- `DeviceContext` creation
- imported-stream caching keyed by `(device_id, native_handle)`
- launch-time validation that the tile memory kind is compatible with the
  direct path

This keeps stream plumbing out of end-user code while still following the
AMReX-selected stream.

## Testing Plan

### Phase 0: prerequisite validation

- confirm that Mojo stdlib can import external CUDA and HIP streams
- confirm that compiled kernels can be launched repeatedly on imported streams

### Phase 1: C ABI and single-tile smoke path

- enable a CUDA-only or HIP-only experimental build
- add C ABI tests for backend detection and current-stream export
- add one direct-kernel smoke test over a single-tile `MultiFab`

### Phase 2: tiled execution and stream rotation

- verify that `MFIter` tile traversal can launch on whichever stream AMReX has
  selected for that tile
- add regression coverage that checks stream changes across multiple tiles

### Phase 3: async lifetime and MPI coverage

- verify that AMReX async allocations remain valid across Mojo launches
- test `fill_boundary(...)` and `parallel_copy_from(...)` after direct launches
- add multi-rank coverage where GPU execution occurs before communication

### Debugging aid

If bring-up is unstable, temporarily test within AMReX's
`SingleStreamRegion`. That can simplify diagnosis, but it should not become the
permanent execution model because it hides stream-rotation behavior that the
real design must handle.

## Fallback if stdlib import is unavailable

If Mojo stdlib does not grow external-stream import support, the only practical
fallback is a bespoke C++ launcher that invokes `cuLaunchKernel` or
`hipModuleLaunchKernel` directly on `amrex::Gpu::gpuStream()`.

That is not the preferred path because it:

- duplicates launch machinery that stdlib already owns
- moves more GPU runtime logic into the C shim
- depends on lower-level Mojo kernel/module handles that are less clearly
  exposed than `DeviceStream.enqueue_function(...)`

The recommended sequence is therefore:

1. add stream import to Mojo stdlib
2. implement the `mojo-amrex` direct path on top of stdlib launches
3. keep the C++ raw-launch fallback only as a contingency option

## Recommendation

The direct AMReX GPU path should be built around one rule:

- launch Mojo kernels on the current AMReX stream against AMReX-owned memory

That keeps AMReX's ownership and scheduling model intact, minimizes boundary
synchronization, and gives `mojo-amrex` a coherent long-term path beyond the
current staged helper design.
