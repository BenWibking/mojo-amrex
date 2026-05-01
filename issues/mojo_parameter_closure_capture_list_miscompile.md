# Legacy captured `@parameter` closures passed to higher-order functions can miscompile or crash

## Summary

I am seeing incorrect runtime behavior when a captured `@parameter` closure is passed to a tiny generic higher-order function.

I reduced this to two `std.collections.List` reproducers that differ only in element type:

- `List[Int]` returns a garbage integer instead of the correct value.
- `List[String]` crashes at runtime instead of returning the correct string.

Both programs compile successfully and both emit a suspicious warning that the captured variable was "never used", even though it is referenced inside the `@parameter` closure.

## Original Mojo Version

`Mojo 0.26.2.0.dev2026030905 (926eca9f)`

## Retest

Retested on `Mojo 1.0.0b1.dev2026043006 (7990276a)` on macOS arm64.

The original legacy `@parameter` / `capturing` form still reproduces both bugs:

- `List[Int]` emitted the unused-assignment warning and printed garbage (`4423974920` in one run).
- `List[String]` emitted the same warning and crashed in `libKGENCompilerRTShared.dylib`.

The checked-in `.mojo` repro files have now been rewritten to the 2026
unified-closure form. With that rewrite:

- `issues/mojo_parameter_closure_capture_list_repro.mojo` prints `2`.
- `issues/mojo_parameter_closure_capture_list_string_crash_repro.mojo` prints `x`.
- Neither rewritten repro emitted the old unused-assignment warning or crashed.

## Platform

macOS arm64

## Wrong-Code Reproducer

Saved as `issues/mojo_parameter_closure_capture_list_repro.mojo`.

The original March 9, 2026 repro used this legacy closure syntax:

```mojo
from std.collections import List


fn apply[body: fn() capturing -> Int]() -> Int:
    return body()


fn main():
    var src = List[Int](length=1, fill=2)

    @parameter
    fn compute() -> Int:
        return src[0]

    print(apply[compute]())
```

## Expected Behavior

The program should print:

```text
2
```

## Actual Behavior

The program compiles, emits a warning that `src` was never used, and prints a garbage integer instead of `2`.

The exact garbage value appears unstable between runs. For example, I have seen:

```text
4470128648
4514103304
```

## Rewritten Unified-Closure Reproducer

The checked-in `issues/mojo_parameter_closure_capture_list_repro.mojo` now uses:

```mojo
from std.collections import List


def apply[body_type: def() raises -> Int](body: body_type) raises -> Int:
    return body()


def main() raises:
    var src = List[Int](length=1, fill=2)

    def compute() raises {var src^} -> Int:
        return src[0]

    print(apply(compute))
```

## Crashing Reproducer

Saved as `issues/mojo_parameter_closure_capture_list_string_crash_repro.mojo`.

```mojo
from std.collections import List


fn apply[body: fn() capturing -> String]() -> String:
    return body()


fn main():
    var src = List[String](length=1, fill=String("x"))

    @parameter
    fn compute() -> String:
        return src[0]

    print(apply[compute]())
```

## Rewritten Unified-Closure Reproducer

The checked-in `issues/mojo_parameter_closure_capture_list_string_crash_repro.mojo` now uses:

```mojo
from std.collections import List


def apply[
    body_type: def() raises -> String
](body: body_type) raises -> String:
    return body()


def main() raises:
    var src = List[String](length=1, fill=String("x"))

    def compute() raises {var src^} -> String:
        return src[0].copy()

    print(apply(compute))
```

## Expected Behavior

The program should print:

```text
x
```

## Actual Behavior

The program compiles, emits the same warning that `src` was never used, and then crashes at runtime inside `libKGENCompilerRTShared.dylib` instead of printing `x`.

## Notes

- The compiler emits a warning that the captured `src` assignment was never used, even though it is referenced inside the `@parameter` closure.
- I originally hit this while wrapping a CPU-only `ParallelFor`, but both reproducers above use only `std.collections.List`, `String`, and a tiny higher-order wrapper.
- These look like two manifestations of the same underlying capture bug: one gives wrong-code, the other escalates to a crash.
- Even if this capture pattern is unsupported internally, compiling it and then producing wrong results or a crash instead of a diagnostic still seems like a compiler bug.
- The unified-closure rewrite avoids the bug by passing the closure as a runtime argument and explicitly transferring the captured `List` into the closure with `{var src^}`.
