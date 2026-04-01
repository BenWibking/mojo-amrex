# Direct GPU Interop for `mojo-amrex`

Last updated: 2026-03-25

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
- Repository examples for this path live at
  `examples/Multifab/multifab_gpu.mojo` and
  `examples/HeatEquation/heat_equation_gpu.mojo`.
- The portable staged path in `mojo/amrex/space3d/gpu.mojo` remains the
  fallback for CPU builds and for backends that do not support direct AMReX
  interop.

## Design

The primary working direction used in this repo is:

- Mojo and AMReX must agree on the same backend device ordinal
- AMReX exposes its current stream handle through the C ABI
- Mojo wraps that AMReX-owned stream with
  `DeviceContext.create_external_stream(...)`
- Mojo and AMReX both issue work onto that same backend stream

Recent Mojo toolchains expose:

- `DeviceContext.create_external_stream(external_stream) -> DeviceStream`
- `DeviceStream.enqueue_function(compiled_kernel, ...)`

That lets Mojo wrap an arbitrary externally owned CUDA or HIP stream handle as a
non-owning `DeviceStream`. The important constraints are:

- the external stream handle must belong to the same device as the active Mojo
  `DeviceContext`
- the returned `DeviceStream` does not own the underlying stream lifetime
- `DeviceStream` does not provide the `DeviceContext.enqueue_function[...]`
  convenience overload that compiles at launch time, so kernels must be
  compiled first with `ctx.compile_function(...)`

In other words, AMReX-owned-stream to Mojo launch order is now expressible as:

- obtain the AMReX stream handle as `void*`
- construct or select the matching Mojo `DeviceContext`
- call `ctx.create_external_stream(handle)`
- compile the kernel with `ctx.compile_function(...)`
- enqueue the compiled kernel on the wrapped `DeviceStream`

That makes the ownership split:

- AMReX owns `MultiFab` storage, async allocation semantics, and ordering
- Mojo owns kernel code generation and wraps the AMReX stream non-owningly

Device selection is stricter than stream selection:

- Mojo exposes device selection through `DeviceContext(device_id=...)`,
  `ctx.id()`, `ctx.push_context()`, and `ctx.set_as_current()`
- AMReX chooses its device at `amrex::Initialize(..., a_device_id)` time and
  reports it later via `Gpu::Device::deviceId()`
- changing Mojo's current device after AMReX initialization does not retarget
  the already-initialized AMReX runtime

So the interoperable path is:

- pick or construct the Mojo `DeviceContext`
- initialize `AmrexRuntime` on `Int(ctx.id())`
- ask AMReX for its current stream handle
- wrap that stream in Mojo and enqueue kernels there

## How It Works

### 1. Backend-gated build

The CMake option `AMREX_MOJO_GPU_BACKEND` controls whether AMReX is built with
`AUTO`, `NONE`, `CUDA`, or `HIP`.

Today:

- `AUTO` selects `CUDA` when a CUDA compiler is detected, otherwise `HIP` when
  a HIP compiler is detected and `AMReX_AMD_ARCH` is available, otherwise
  `NONE`
- `AUTO` fills `AMReX_AMD_ARCH` from `rocminfo` when possible
- `CUDA` works
- `HIP` works when configured with `-DAMReX_AMD_ARCH=<gfx*>` or when that value
  can be autodetected

### 2. AMReX exports the native stream handle

At the C ABI layer, `amrex_mojo_gpu_stream()` returns the current
`amrex::Gpu::gpuStream()` value as `void*`. The Mojo wrapper exposes that as
`AmrexRuntime.gpu_stream_handle(ctx)`.

That means:

- Mojo sees the actual stream AMReX will use for GPU work
- AMReX stream selection remains the source of truth
- the Mojo wrapper rejects mismatched backend or device contexts before
  exposing the raw handle

### 3. Mojo wraps that stream as a `DeviceStream`

At the Mojo layer, `ctx.create_external_stream(runtime.gpu_stream_handle(ctx))`
constructs a non-owning `DeviceStream` for the current AMReX stream.

That means:

- AMReX work such as `setVal`, `FillBoundary`, and `ParallelCopy` stays on the
  stream AMReX already selected
- Mojo kernels compiled with `ctx.compile_function(...)` can be enqueued onto
  that same stream with `DeviceStream.enqueue_function(...)`
- explicit synchronization should happen on the wrapped `DeviceStream` before
  host-visible uses such as plotfile output or teardown

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
    var ctx = DeviceContext()
    var runtime = AmrexRuntime(Int(ctx.id()))
    var amrex_stream = ctx.create_external_stream(
        runtime.gpu_stream_handle(ctx)
    )
    var kernel = ctx.compile_function[my_kernel, my_kernel]()

    # Borrow device views from a GPU-backed MultiFab and enqueue Mojo kernels on
    # the AMReX-owned stream while AMReX calls use that same stream.
```

Within that flow:

- AMReX operations such as `setVal`, reductions, `FillBoundary`, or
  `ParallelCopy` issue work on the current AMReX stream
- Mojo kernels enqueued on the wrapped `DeviceStream` see the same ordering

What does not work as an interop setter:

- `ctx.set_as_current()` is useful for libraries that consult the current CUDA
  or HIP context directly, but it does not update AMReX's stored
  `Gpu::Device::deviceId()`
- after AMReX is initialized, switching the Mojo current device alone is not a
  valid way to retarget AMReX allocations or launches

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
- direct interop is only meaningful for device-accessible `MultiFab`
  allocations
- the current Mojo `DeviceContext` and initialized AMReX runtime must point to
  the same device ordinal
- `DeviceStream` does not provide the `DeviceContext.enqueue_function[...]`
  convenience overload, so kernels must be compiled first and then enqueued
  explicitly

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
