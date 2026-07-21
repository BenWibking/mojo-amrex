# `OwnedDLHandle.call` aggregate-by-value reproducer

This standalone reproducer demonstrates that `OwnedDLHandle.call` does not use
the C ABI when passing an aggregate struct by value. It consists of a tiny C
dynamic library and a Mojo caller, and does not depend on AMReX.

## Build and run on macOS

With `mojo` available directly, run these commands from this directory:

```console
cc -dynamiclib aggregate.c -o libaggregate.dylib
mojo reproducer.mojo
```

From the `mojo-amrex` repository root, the equivalent Pixi commands are:

```console
cc -dynamiclib issues/OwnedDLHandleAggregate/aggregate.c \
  -o issues/OwnedDLHandleAggregate/libaggregate.dylib
pixi run bash -lc 'cd issues/OwnedDLHandleAggregate && mojo reproducer.mojo'
```

## Expected result

```text
pointer control: 45
by value:       45
```

## Actual result

With Mojo `1.0.0b3.dev2026072114 (5d4c50d9)` on Apple Silicon, the pointer
control succeeds and execution then crashes while calling `sum_aggregate`:

```text
pointer control: 45
mojo: error: execution crashed
```

The aggregate contains nine `int32_t` fields so that it is passed indirectly by
the platform C ABI. Scalar arguments, or passing the aggregate through a
pointer, avoid the problem.
