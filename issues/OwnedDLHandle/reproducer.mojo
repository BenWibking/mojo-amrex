# ABOUTME: Reproduces indirect calls through OwnedDLHandle.get_function returning the function value.
# ABOUTME: This is standalone and depends only on macOS libSystem and the Mojo standard library.

from std.ffi import OwnedDLHandle


def main() raises:
    var lib = OwnedDLHandle("/usr/lib/libSystem.B.dylib")
    var abs = lib.get_function[def(Int32) thin abi("C") -> Int32]("abs")
    print(abs(Int32(-7)))
