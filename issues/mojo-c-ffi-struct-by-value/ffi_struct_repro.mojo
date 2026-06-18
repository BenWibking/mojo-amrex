from std.builtin.device_passable import DevicePassable, DeviceTypeEncoder
from std.ffi import OwnedDLHandle, c_int
from std.os.path import exists


comptime Token = UnsafePointer[NoneType, MutUntrackedOrigin]


def init_device_passable_value[
    T: TrivialRegisterPassable,
    mut_origin: MutOrigin,
](value: T, target: UnsafePointer[NoneType, mut_origin]):
    target.bitcast[T]().init_pointee_copy(value)


@fieldwise_init
struct Int3(DevicePassable, TrivialRegisterPassable):
    comptime device_type = Self

    var x: c_int
    var y: c_int
    var z: c_int

    def _to_device_type(
        self,
        mut encoder: Some[DeviceTypeEncoder],
        target: UnsafePointer[mut=True, NoneType, _],
    ):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("Int3")


def token_a(ref lib: OwnedDLHandle) raises -> Token:
    return lib.call["token_a", Token]()


def token_b(ref lib: OwnedDLHandle) raises -> Token:
    return lib.call["token_b", Token]()


def last_arg_a(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["last_arg_a", c_int]())


def last_arg_b(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["last_arg_b", c_int]())


def last_arg_c(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["last_arg_c", c_int]())


def last_arg_x(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["last_arg_x", c_int]())


def last_arg_y(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["last_arg_y", c_int]())


def last_arg_z(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["last_arg_z", c_int]())


def check_struct_early(ref lib: OwnedDLHandle, p0: Token, p1: Token, value: Int3) raises -> Int:
    var f = lib.get_function[def(Token, Token, Int3) thin abi("C") -> c_int]("check_struct_early")
    return Int(f(p0, p1, value))


def check_struct_after_five(ref lib: OwnedDLHandle, p0: Token, p1: Token, value: Int3) raises -> Int:
    var f = lib.get_function[def(Token, Token, c_int, c_int, c_int, Int3) thin abi("C") -> c_int](
        "check_struct_after_five"
    )
    return Int(f(p0, p1, c_int(101), c_int(202), c_int(303), value))


def check_scalars_after_five(ref lib: OwnedDLHandle, p0: Token, p1: Token, value: Int3) raises -> Int:
    var f = lib.get_function[def(Token, Token, c_int, c_int, c_int, c_int, c_int, c_int) thin abi("C") -> c_int](
        "check_scalars_after_five"
    )
    return Int(
        f(
            p0,
            p1,
            c_int(101),
            c_int(202),
            c_int(303),
            value.x,
            value.y,
            value.z,
        )
    )


def print_observed(ref lib: OwnedDLHandle) raises:
    print(
        "observed=(a=",
        last_arg_a(lib),
        ", b=",
        last_arg_b(lib),
        ", c=",
        last_arg_c(lib),
        ", x=",
        last_arg_x(lib),
        ", y=",
        last_arg_y(lib),
        ", z=",
        last_arg_z(lib),
        ")",
    )


def expect_ok(ref lib: OwnedDLHandle, label: StringLiteral, status: Int) raises:
    print(label, "status=", status)
    print_observed(lib)
    if status != 0:
        raise Error(label + " failed")


def main() raises:
    var lib_path = String("./libffi_struct_repro.so")
    if not exists(lib_path):
        lib_path = "issues/mojo-c-ffi-struct-by-value/libffi_struct_repro.so"
    var lib = OwnedDLHandle(lib_path)
    var p0 = token_a(lib)
    var p1 = token_b(lib)
    var value = Int3(x=c_int(11), y=c_int(22), z=c_int(33))

    expect_ok(lib, "struct_early", check_struct_early(lib, p0, p1, value))
    expect_ok(lib, "scalars_after_five", check_scalars_after_five(lib, p0, p1, value))
    expect_ok(lib, "struct_after_five", check_struct_after_five(lib, p0, p1, value))

    print("all checks passed")
