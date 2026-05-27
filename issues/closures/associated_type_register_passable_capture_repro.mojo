from std.builtin.device_passable import DevicePassable


trait ValueTag:
    comptime value_type: AnyType

    @staticmethod
    def get() -> Self.value_type:
        ...


struct RealTag(ValueTag):
    comptime value_type = Float64

    @staticmethod
    def get() -> Float64:
        return 0.01


def get_value[T: ValueTag]() -> T.value_type:
    return T.get()


def use_closure[
    body_type: (def(Int) -> None) & DevicePassable
](body: body_type):
    body(0)


def main():
    var dt = get_value[RealTag]()

    def body(i: Int) {var dt}:
        _ = Float64(i) + dt

    use_closure(body)
