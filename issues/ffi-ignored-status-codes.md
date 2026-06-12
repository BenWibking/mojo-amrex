# Several FFI wrappers discard the C status code and return zero-filled data on failure

**Severity: Medium-Low** (latent: current callers pre-validate handles, but failures decay into garbage values instead of errors)

## Explanation

Three wrappers in `mojo/amrex/ffi.mojo` ignore the `amrex_mojo_status_code_t`
returned by the C API:

1. `multifab_memory_info` (`ffi.mojo:608-618`): `_ = lib.call[...]`. If the C
   call fails (e.g. stale handle), `raw` stays all-zeros and the caller receives
   a `MultiFabMemoryInfo` claiming the multifab is neither host- nor
   device-accessible — `MultiFab.memory_info()` then returns it as fact.

2. `_array4_view_from_mfiter_impl` (`ffi.mojo:769-786`): the
   `amrex_mojo_multifab_array4_metadata_for_mfiter` status is discarded. On
   failure the layout is all zeros (`stride_i == 0`, `ncomp == 0`). Today the
   subsequent data-pointer call fails for the same root causes and raises, but
   that coupling is accidental: any future divergence (e.g. a metadata-only
   failure) yields an `Array4View` whose every `offset()` is 0, silently
   aliasing all indices onto the first element.

3. `mfiter_create` (`ffi.mojo:647-653`): status discarded; benign today because
   the out-handle starts as `None` and callers check the `Optional`, but the
   error message from `last_error_message` is lost — `create_mfiter` re-reads it
   only because the C side leaves it set.

## Proposed patch

Check each status with the existing helper:

```mojo
def multifab_memory_info(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises -> MultiFabMemoryInfo:
    var raw = List[c_int](length=6, fill=0)
    raise_on_error(
        lib,
        Int(lib.call["amrex_mojo_multifab_memory_info", c_int](multifab, raw.unsafe_ptr())),
    )
    ...
```

and likewise wrap the metadata call in `_array4_view_from_mfiter_impl` and the
create call in `mfiter_create` with `raise_on_error`.
