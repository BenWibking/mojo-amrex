# Direct GPU Interop for `mojo-amrex`

Last updated: 2026-03-14

## Goal

Launch Mojo GPU kernels directly against AMReX-managed `MultiFab` device
storage without staging tile data through Mojo `DeviceBuffer`s.

## Status

This repository now implements an opt-in direct CUDA/HIP path.

- `pixi run bootstrap` / `pixi run configure` now default
  `AMREX_MOJO_GPU_BACKEND` to `AUTO`, which probes for CUDA first, then HIP,
  and falls back to `NONE` if neither toolchain is available.
- Direct interop is available when AMReX is configured with
  `AMREX_MOJO_GPU_BACKEND=CUDA` or `AMREX_MOJO_GPU_BACKEND=HIP`.
- The portable staged path in `mojo/amrex/space3d/gpu.mojo` remains the
  fallback for CPU builds and for backends that do not support direct AMReX
  interop.

## Design

The working direction is:

- Mojo exports a raw handle for its current stream
- AMReX adopts that stream for a scoped region with
  `setExternalGpuStream` / `ExternalGpuStreamRegion`
- Mojo and AMReX both issue work onto that same backend stream

The inverse direction is not currently used here. AsyncRT still does not expose
a working external-stream import path that would let `mojo-amrex` wrap an
arbitrary AMReX-owned stream as a Mojo `DeviceStream`.

That makes the ownership split:

- AMReX owns `MultiFab` storage, async allocation semantics, and ordering
- Mojo owns kernel code generation and the stream handle it exports

## How It Works

### 1. Backend-gated build

The CMake option `AMREX_MOJO_GPU_BACKEND` controls whether AMReX is built with
`AUTO`, `NONE`, `CUDA`, or `HIP`.

Today:

- `AUTO` selects `CUDA` when a CUDA compiler is detected, otherwise `HIP` when
  a HIP compiler is detected, otherwise `NONE`
- `CUDA` works
- `HIP` works

### 2. Mojo exports the native stream handle

At the Mojo layer, `AmrexRuntime.external_gpu_stream_scope(ctx, ...)` inspects
`ctx.api()` and exports the native stream handle from the current Mojo stream.

Current implementation:

- CUDA: `std.gpu.host._nvidia_cuda.CUDA(ctx.stream()) -> CUstream`
- HIP: `std.gpu.host._amdgpu_hip.HIP(ctx.stream()) -> hipStream_t`

Those typed handles are erased to `void*` for the C ABI boundary.

Important caveat:

- those Mojo modules are internal stdlib modules in the currently installed
  toolchain for this repo
- they are the mechanism that works today, but they are not a stable public API

If a stable public stdlib export surface becomes available later, the AMReX
side of this design does not need to change.

### 3. AMReX installs that stream as the current external stream

The C ABI function
`amrex_mojo_external_gpu_stream_scope_create(stream_handle, sync_on_exit)`
constructs an AMReX `ExternalGpuStreamRegion`.

That means:

- every AMReX GPU launch in that scope uses the Mojo stream handle
- `resetExternalGpuStream(...)` happens automatically when the scope is
  destroyed

The `sync_on_exit` flag is forwarded to AMReX's
`ExternalStreamSync::{Yes,No}` behavior:

- `True` is conservative and synchronizes on teardown
- `False` avoids an unconditional sync, although AMReX may still synchronize if
  deferred async frees require it

### 4. Device borrows expose pointer-and-shape metadata

The direct path does not pass `MultiFab` or `FArrayBox` objects into Mojo.
Instead it borrows:

- tile box metadata
- valid box metadata
- `Array4` bounds and strides
- the raw data pointer for a device-accessible tile

The relevant high-level wrappers are:

- `MultiFab.unsafe_device_array(tile_index)`
- `MultiFab.unsafe_device_array(mfi)`
- `MultiFabF32.unsafe_device_array(tile_index)`
- `MultiFabF32.unsafe_device_array(mfi)`

Those methods call C accessors that explicitly require
`arena->isDeviceAccessible()`.

## Typical Flow

```mojo
from amrex.runtime import AmrexRuntime
from std.gpu.host import DeviceContext

fn main() raises:
    var runtime = AmrexRuntime()
    var ctx = DeviceContext()

    # Install the current Mojo stream as AMReX's active stream for this scope.
    var stream_scope = runtime.external_gpu_stream_scope(
        ctx, sync_on_exit=False
    )

    # Borrow device views from a GPU-backed MultiFab and launch Mojo kernels on
    # ctx.stream() while AMReX calls in this scope use that same stream.
```

Within that scope:

- AMReX operations such as `setVal`, reductions, `FillBoundary`, or
  `ParallelCopy` issue work on the exported Mojo stream
- Mojo kernels launched on `ctx.stream()` see the same ordering

## Why The API Is Marked `unsafe`

The current device borrow path reuses the same `Array4F32View` and
`Array4F64View` data structures as the host path.

That is convenient for device passage, but it means the type still has host
indexing helpers such as:

- `__getitem__`
- `__setitem__`
- `fill(...)`

Those are not safe on device-only storage.

So the contract is:

- use `array(...)` and `tile(...)` for host-accessible storage
- use `unsafe_device_array(...)` only as device-passable pointer/shape metadata
- do not dereference the returned pointer from host code

Dedicated device-only view types would be a cleaner long-term surface, but the
current explicit `unsafe_...` naming is enough to support the direct path
without hiding the risk.

## Limits and Caveats

- CUDA and HIP only for now
- AMReX's external-stream override is not supported inside OpenMP parallel
  regions
- direct interop is only meaningful for device-accessible `MultiFab`
  allocations
- the current path is Mojo-stream-to-AMReX, not arbitrary external-stream
  import into Mojo
- the current Mojo raw-handle export path depends on internal stdlib modules

## Fallback Path

When direct AMReX GPU interop is unavailable, the supported fallback remains:

1. borrow a host `Array4`
2. stage it through a Mojo `DeviceBuffer`
3. launch the Mojo kernel
4. copy the result back

That staged path is slower, but it remains useful for:

- CPU-only AMReX builds
- Metal backends
- bring-up and debugging
- any environment where the current toolchain does not expose the needed CUDA
  or HIP stream exports
