"""CPU-only `ParallelFor` helpers for 3D tile boxes."""

from amrex.ffi import Box3D


def ParallelFor[
    body: def(Int, Int, Int) capturing -> None
](tile_box: Box3D) raises:
    for k in range(Int(tile_box.small_end.z), Int(tile_box.big_end.z) + 1):
        for j in range(Int(tile_box.small_end.y), Int(tile_box.big_end.y) + 1):
            for i in range(
                Int(tile_box.small_end.x), Int(tile_box.big_end.x) + 1
            ):
                body(i, j, k)


def ParallelFor[
    body: def(Int, Int, Int) raises capturing -> None
](tile_box: Box3D) raises:
    for k in range(Int(tile_box.small_end.z), Int(tile_box.big_end.z) + 1):
        for j in range(Int(tile_box.small_end.y), Int(tile_box.big_end.y) + 1):
            for i in range(
                Int(tile_box.small_end.x), Int(tile_box.big_end.x) + 1
            ):
                body(i, j, k)


def ParallelFor[
    ctx_type: Copyable,
    body: def(ctx_type, Int, Int, Int) capturing -> None,
](tile_box: Box3D, ctx: ctx_type) raises:
    for k in range(Int(tile_box.small_end.z), Int(tile_box.big_end.z) + 1):
        for j in range(Int(tile_box.small_end.y), Int(tile_box.big_end.y) + 1):
            for i in range(
                Int(tile_box.small_end.x), Int(tile_box.big_end.x) + 1
            ):
                body(ctx, i, j, k)


def ParallelFor[
    ctx_type: Copyable,
    body: def(ctx_type, Int, Int, Int) raises capturing -> None,
](tile_box: Box3D, ctx: ctx_type) raises:
    for k in range(Int(tile_box.small_end.z), Int(tile_box.big_end.z) + 1):
        for j in range(Int(tile_box.small_end.y), Int(tile_box.big_end.y) + 1):
            for i in range(
                Int(tile_box.small_end.x), Int(tile_box.big_end.x) + 1
            ):
                body(ctx, i, j, k)
