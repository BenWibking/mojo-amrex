# ABOUTME: Reproduces the DeviceStream closure-argument regression.
# ABOUTME: Passes a captured closure to a compiled kernel on a Mojo-owned stream.

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
