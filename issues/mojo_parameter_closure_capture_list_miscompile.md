# Captured `@parameter` closures passed to higher-order functions can miscompile or crash

## Summary

I am seeing incorrect runtime behavior when a captured `@parameter` closure is passed to a tiny generic higher-order function.

I reduced this to two `std.collections.List` reproducers that differ only in element type:

- `List[Int]` returns a garbage integer instead of the correct value.
- `List[String]` crashes at runtime instead of returning the correct string.

Both programs compile successfully and both emit a suspicious warning that the captured variable was "never used", even though it is referenced inside the `@parameter` closure.

## Mojo Version

`Mojo 0.26.2.0.dev2026030905 (926eca9f)`

## Platform

macOS arm64

## Wrong-Code Reproducer

Saved as `issues/mojo_parameter_closure_capture_list_repro.mojo`.

The snippets below intentionally preserve the original March 9, 2026
`fn`-based syntax from the bug report. The checked-in `.mojo` repro files have
since been migrated to equivalent `def` syntax where the current toolchain
accepts it.

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
