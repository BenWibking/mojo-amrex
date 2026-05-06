# Unified closure capture of packaged `Copyable` struct crashes compiler

## Summary

On `Mojo 1.0.0b1.dev2026043006`, a nested unified closure crashes the
compiler when its explicit capture list consumes a `Copyable` struct imported
from a `.mojopkg` with `{var value^}`.

I hit this while rewriting a `ParallelFor`-style iterator to pass Mojo closures
as runtime values. Capturing values from a source-defined struct in the same
file works. Capturing an instance of the same shape imported from a compiled
package crashes while resolving the nested closure signature.

## Version

`Mojo 1.0.0b1.dev2026043006 (7990276a)`

## Platform

macOS arm64

## Reproducer

Package source saved as `issues/closures/mojo_closure_capture_pkg_src/__init__.mojo`:

```mojo
struct Box(Copyable):
    def __init__(out self):
        pass
```

Driver saved as
`issues/closures/mojo_unified_closure_imported_copyable_capture_crash_repro.mojo`:

```mojo
from mojo_closure_capture_pkg import Box

def main() raises:
    var box = Box()

    def use_box() raises {var box^}:
        pass
```

Run from this repository:

```text
pixi run mojo package issues/closures/mojo_closure_capture_pkg_src -o /tmp/mojo_closure_capture_pkg.mojopkg
pixi run mojo -I /tmp issues/closures/mojo_unified_closure_imported_copyable_capture_crash_repro.mojo
```

For comparison, the same struct and closure in a single source file compiles
successfully:

```mojo
struct Box(Copyable):
    def __init__(out self):
        pass


def main() raises:
    var box = Box()

    def use_box() raises {var box^}:
        pass
```

So the crash appears to require loading the captured type from a compiled
package.

## Expected Behavior

The driver should compile successfully.

## Actual Behavior

The compiler exits with status 139 while resolving the nested closure
signature.

Stack excerpt:

```text
Please submit a bug report to https://github.com/modular/modular/issues and include the crash backtrace along with all the relevant source codes.
Stack dump:
0. Program arguments: .../bin/mojo -I /tmp issues/closures/mojo_unified_closure_imported_copyable_capture_crash_repro.mojo
1. Crash resolving decl body at .../issues/closures/mojo_unified_closure_imported_copyable_capture_crash_repro.mojo:4:5
2. Crash parsing statement at .../issues/closures/mojo_unified_closure_imported_copyable_capture_crash_repro.mojo:7:5
   def use_box() raises {var box^}:
3. Crash resolving decl signature at .../issues/closures/mojo_unified_closure_imported_copyable_capture_crash_repro.mojo:7:9
```

## Original AMReX Trigger

The original application-level crash used this shape:

```mojo
from amrex.ffi import RealVect3D


def main() raises:
    var dx = RealVect3D(x=1.0, y=2.0, z=3.0)

    def use_dx() raises {var dx^}:
        _ = dx.x
```

after building the local `amrex.mojopkg`. The minimal package reproducer above
shows that AMReX is not required.

## Notes

- A higher-order wrapper is not required; the crash happens while resolving the
  nested closure signature.
- Struct fields are not required; an empty `Copyable` struct is enough.
- The closure does not need to be called, and the captured value does not need
  to be referenced in the closure body.
- Capturing individual scalar fields avoids the original AMReX crash, which is
  why the workaround is easy to miss in application code.
- The same crash appears in `examples/HeatEquation/heat_equation.mojo` when
  its `ParallelFor` body captures `tile_dx^` directly.
