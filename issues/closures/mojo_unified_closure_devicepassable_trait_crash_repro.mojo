from std.builtin.device_passable import DevicePassable


def call_cell[body_type: (def(Int, Int, Int) -> None) & DevicePassable](body: body_type):
    body(0, 0, 0)


def main():
    var value = 1

    def cell(i: Int, j: Int, k: Int) {read value}:
        _ = i + j + k + value

    call_cell(cell)
