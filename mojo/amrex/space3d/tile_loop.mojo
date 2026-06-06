"""Canonical type constraint for 3D tile `(i, j, k)` parallel kernels.

Use `TileLoopBody` as the documented name for this constraint when writing new
tile APIs or reading existing ones. Package internals still spell the constraint
inline in generic bounds because Mojo does not yet preserve witness tables when
a `comptime` alias is used as the parameter type and the kernel is invoked from
another generic function (see `for_each_box_cell` and `_parallel_for_cpu`).
"""

from std.builtin.device_passable import DevicePassable


comptime TileLoopBody = (def(Int, Int, Int) -> None) & DevicePassable & ImplicitlyCopyable
