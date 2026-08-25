# [BUG] Compiler regression: `DeviceStream.enqueue_function` rejects `DevicePassable` closure arguments

## Bug description

### Actual behavior

Passing an `ImplicitlyCopyable & DevicePassable` closure as a runtime argument
to an explicitly compiled GPU kernel fails during `DeviceStream.enqueue_function`
instantiation:

```text
constraint failed: argument #0 of type 'closure' (which became device of type
'closure') does not match the declared function argument type
```

This is a compiler regression. The reproducer below runs successfully with
Mojo `1.0.0b3.dev2026080206`, but fails with
`1.0.0b3.dev2026080400`, later nightlies, and stable Mojo `1.0.0`.

### Expected behavior

`DeviceStream.enqueue_function()` should accept the closure because its type
satisfies the kernel's declared `DevicePassable & ImplicitlyCopyable` argument
constraint. The kernel should run and print `42`, as it does with the last-good
nightly.

## Steps to reproduce

Save the following as `repro.mojo`:

```mojo
from std.builtin.device_passable import DevicePassable
from max.gpu.host import DeviceContext


def call_closure[
    closure_type: (def() -> None) & DevicePassable & ImplicitlyCopyable
](closure: closure_type):
    closure()


def main() raises:
    var ctx = DeviceContext()
    var stream = ctx.create_stream()
    var captured = Int32(42)

    def closure() {var captured}:
        print(captured)

    comptime kernel = call_closure[type_of(closure)]
    var compiled_kernel = ctx.compile_function[kernel]()
    stream.enqueue_function(
        compiled_kernel,
        closure,
        grid_dim=1,
        block_dim=1,
    )
    stream.synchronize()
```

Run it with stable Mojo:

```bash
mojo repro.mojo
```

The relevant diagnostic is:

```text
error: function instantiation failed
def main() raises:
    ^
note: call expansion failed with parameter value(s): (..., ..., ..., ..., ...)
    stream.enqueue_function(
                           ^
max/mojo/max/gpu/host/device_context.mojo:3170:17: note: constraint failed:
argument #0 of type 'closure' (which became device of type 'closure') does not
match the declared function argument type
mojo: error: failed to run the pass manager
```

## Regression range

| Mojo | MAX Core | Result |
|---|---|---|
| `1.0.0b3.dev2026080206` (`7db826ea`) | `26.5.0.dev2026080206` | Passes; prints `42` |
| `1.0.0b3.dev2026080400` (`32847669`) | `26.5.0.dev2026080400` | Fails with the diagnostic above |
| `1.0.0b3.dev2026080406` (`df531e54`) | `26.5.0.dev2026080406` | Fails |
| `1.0.0` (`ed45d567`) | `26.5.0` | Fails |

There is no August 3 nightly in the package channel, so
`1.0.0b3.dev2026080400` is the first available bad nightly after the
last-good `1.0.0b3.dev2026080206` build.

For the last-good build, the only required source change is the historical
import location:

```mojo
from std.gpu.host import DeviceContext
```

The regression boundary coincides with commit
[`992cccd`](https://github.com/modular/modular/commit/992cccd02cdffd5b03d642d5453a968160bbf471),
which moved `std.gpu.host` into `max.gpu.host`. This may indicate a type-identity
or device-argument encoding problem across the new package boundary rather than
an intentional API change.

## System information

```text
Mojo 1.0.0 (ed45d567)

Pixi version: 0.73.0
Platform: linux-64
Linux: 5.15.0
glibc: 2.35
Architecture: x86_64 / zen4
CUDA virtual package: 13.0

GPU: NVIDIA H200 (compute capability 9.0)
NVIDIA driver: 580.173.02
```

Output of `pixi list max`:

```text
Installed for: linux-64
Name      Version  Build          Size  Kind   Source
max-core  26.5.0   release  112.14 MiB  conda  https://conda.modular.com/max
```
