# Mojo issue repro status

Last retested: 2026-05-24 with Mojo `1.0.0b2.dev2026052406 (90479b6a)`.

This directory tracks small reproducers for upstream Mojo issues filed against
`modular/modular`. The status below is the local repro status on the tested
nightly, not necessarily the GitHub issue state. At the time of retesting, all
linked upstream issues were still open.

## Fixed in the tested nightly

| Local repro | Upstream issue | Local result |
| --- | --- | --- |
| [`mojo-c-ffi-struct-by-value/`](mojo-c-ffi-struct-by-value/) | [modular/modular#6567](https://github.com/modular/modular/issues/6567) | After updating the repro for the current `DevicePassable` API, `pixi run make -C issues/mojo-c-ffi-struct-by-value run-mojo` passes, including the formerly failing `struct_after_five` case. |

## Still open locally

| Local repro | Upstream issue | Local result |
| --- | --- | --- |
| [`closures/associated_type_register_passable_capture_repro.mojo`](closures/associated_type_register_passable_capture_repro.mojo) | [modular/modular#6592](https://github.com/modular/modular/issues/6592) | Still fails with a missing `ImplicitlyDestructible.__del__` witness when capturing an associated-type return value in a `DevicePassable` closure. |
| [`metal/apple_silicon_zero_copy_host_buffer_gpu_repro.mojo`](metal/apple_silicon_zero_copy_host_buffer_gpu_repro.mojo) | [modular/modular#6145](https://github.com/modular/modular/issues/6145) | Not confirmed fixed. After updating the repro for the current `DevicePassable` API and running outside the sandbox, Mojo fails earlier with `Metal Compiler failed to compile metallib`. |

The Objective-C Metal harness in [`metal/metal_zero_copy_tests.m`](metal/metal_zero_copy_tests.m) passed all 28 cases outside the sandbox on an Apple M1 Pro during the same retest. That suggests the raw Metal shared-buffer behavior is healthy on this machine, while the Mojo Metal repro remains blocked before it can test the original zero-copy behavior.
