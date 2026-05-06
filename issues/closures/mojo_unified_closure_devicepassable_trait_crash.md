# Mojo unified closure DevicePassable trait crash

Observed with:

```text
Mojo 1.0.0b2.dev2026050616 (a938bf06)
```

The compiler reports that a unified closure cannot bind to
`def(Int, Int, Int) -> None & DevicePassable`, then segfaults during parameter
inference for the call.

Reproducer command from the repository root:

```bash
pixi run mojo build --target-accelerator sm_80 issues/closures/mojo_unified_closure_devicepassable_trait_crash_repro.mojo -o /tmp/mojo_unified_closure_devicepassable_trait_crash_repro
```

Expected behavior: a normal diagnostic, or successful binding if unified
closures with device-passable captures are intended to satisfy the function
trait intersection.

Actual behavior: diagnostic followed by compiler crash.
