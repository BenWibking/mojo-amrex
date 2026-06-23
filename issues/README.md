# Mojo issue repro status

Last retested: 2026-06-22 with Mojo `1.0.0b3.dev2026062206 (054ded55)`.

This directory tracks small reproducers for upstream Mojo issues filed against
`modular/modular`. The status below is the local repro status on the tested
nightly, not necessarily the GitHub issue state. At the time of retesting, all
linked upstream issues were still open.

## Fixed in the tested nightly

| Local repro | Upstream issue | Local result |
| --- | --- | --- |
| [`mojo-c-ffi-struct-by-value/`](mojo-c-ffi-struct-by-value/) | [modular/modular#6567](https://github.com/modular/modular/issues/6567) | Fixed in the current nightly: `struct_early`, `scalars_after_five`, and `struct_after_five` all return status 0 with the expected values, then `all checks passed`. |
| [`closures/associated_type_register_passable_capture_repro.mojo`](closures/associated_type_register_passable_capture_repro.mojo) | [modular/modular#6592](https://github.com/modular/modular/issues/6592) | Fixed in the current nightly: the repro completes without a witness error. |

## Still open locally

| Local repro | Upstream issue | Local result |
| --- | --- | --- |
| [`metal/apple_silicon_zero_copy_host_buffer_gpu_repro.mojo`](metal/apple_silicon_zero_copy_host_buffer_gpu_repro.mojo) | [modular/modular#6145](https://github.com/modular/modular/issues/6145) | Not confirmed fixed here: on this Linux host the repro now stops earlier with a compile-time `AnyOrigin` field error, so it does not reach the original Apple Silicon GPU behavior. |

The Objective-C Metal harness in [`metal/metal_zero_copy_tests.m`](metal/metal_zero_copy_tests.m) passed all 28 cases outside the sandbox on an Apple M1 Pro during the same retest. That suggests the raw Metal shared-buffer behavior is healthy on this machine, while the Mojo Metal repro remains blocked before it can test the original zero-copy behavior.
