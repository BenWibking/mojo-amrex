# `OwnedDLHandle.get_function` callable invocation regression check

This standalone check uses the current `OwnedDLHandle.get_function` API to load
`abs` from macOS `libSystem` and invoke the returned callable. It does not
depend on AMReX or any files outside this directory.

## Run

```console
mojo reproducer.mojo
```

## Expected result

```text
7
```

## Compatibility history

With Mojo `1.0.0b3.dev2026072006 (7d0f0c04)`, compilation fails because
`abs(Int32(-7))` evaluates to the function value instead of invoking it:

```text
error: invalid call to 'print': an element of 'values' with type
'def(Int32) abi("C") thin -> Int32' does not conform to trait 'Writable'
```

The equivalent direct lookup and call succeeds:

```mojo
print(lib.call["abs", Int32](Int32(-7)))
```

Mojo `1.0.0b3.dev2026073014` fixes argument forwarding for
`OwnedDLHandle.get_function` and changes its type parameter from the complete
function type to the return type. The checked-in source uses the new API and
prints `7`.
