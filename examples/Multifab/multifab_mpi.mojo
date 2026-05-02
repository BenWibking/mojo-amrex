from amrex.space3d import (
    AmrexRuntime,
    Array4F64View,
    Box3D,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParmParse,
    box3d,
    intvect3d,
)
from std.collections import List


comptime DOMAIN_EXTENT = 64
comptime SLAB_EXTENT = DOMAIN_EXTENT // 2
comptime CELLS_PER_SLAB = SLAB_EXTENT * DOMAIN_EXTENT * DOMAIN_EXTENT


def expect(condition: Bool, message: StringLiteral) raises:
    if not condition:
        raise Error(message)


def expect_close(
    actual: Float64,
    expected: Float64,
    tolerance: Float64,
    message: StringLiteral,
) raises:
    var delta = actual - expected
    if delta < 0.0:
        delta = -delta
    expect(delta <= tolerance, message)


def fill_box_value[
    owner_origin: Origin[mut=True]
](array: Array4F64View[owner_origin], box: Box3D, value: Float64) raises:
    for k in range(Int(box.small_end.z), Int(box.big_end.z) + 1):
        for j in range(Int(box.small_end.y), Int(box.big_end.y) + 1):
            for i in range(Int(box.small_end.x), Int(box.big_end.x) + 1):
                array[i, j, k] = value


def slab_fill_value(box: Box3D, left_value: Int, right_value: Int) raises -> Float64:
    if Int(box.small_end.x) == 0:
        return Float64(left_value)
    return Float64(right_value)


def slab_neighbor_value(box: Box3D, left_value: Int, right_value: Int) raises -> Float64:
    if Int(box.small_end.x) == 0:
        return Float64(right_value)
    return Float64(left_value)


def box_contains(box: Box3D, i: Int, j: Int, k: Int) raises -> Bool:
    return (
        i >= Int(box.small_end.x)
        and i <= Int(box.big_end.x)
        and j >= Int(box.small_end.y)
        and j <= Int(box.big_end.y)
        and k >= Int(box.small_end.z)
        and k <= Int(box.big_end.z)
    )


def has_nonzero_ghost_cells(mut multifab: MultiFab) raises -> Bool:
    var mfi = multifab.mfiter()
    while mfi.is_valid():
        var valid_box = mfi.validbox()
        var fab_box = mfi.fabbox()
        var array = multifab.array(mfi)
        for k in range(Int(fab_box.small_end.z), Int(fab_box.big_end.z) + 1):
            for j in range(Int(fab_box.small_end.y), Int(fab_box.big_end.y) + 1):
                for i in range(
                    Int(fab_box.small_end.x),
                    Int(fab_box.big_end.x) + 1,
                ):
                    if not box_contains(valid_box, i, j, k) and array[i, j, k] != 0.0:
                        return True
        mfi.next()

    return False


def interface_ghost_sample(mut multifab: MultiFab) raises -> Float64:
    var mfi = multifab.mfiter()
    while mfi.is_valid():
        var valid_box = mfi.validbox()
        var array = multifab.array(mfi)
        var j = Int(valid_box.small_end.y)
        var k = Int(valid_box.small_end.z)
        if Int(valid_box.small_end.x) == 0:
            return array[Int(valid_box.big_end.x) + 1, j, k]
        if Int(valid_box.big_end.x) == DOMAIN_EXTENT - 1:
            return array[Int(valid_box.small_end.x) - 1, j, k]
        mfi.next()

    raise Error("expected a local tile touching the slab interface")


def interface_expected_value(mut multifab: MultiFab, left_value: Int, right_value: Int) raises -> Float64:
    var mfi = multifab.mfiter()
    while mfi.is_valid():
        var valid_box = mfi.validbox()
        if Int(valid_box.small_end.x) == 0 or Int(valid_box.big_end.x) == DOMAIN_EXTENT - 1:
            return slab_neighbor_value(valid_box, left_value, right_value)
        mfi.next()

    raise Error("expected a local tile touching the slab interface")


def main() raises:
    var argv = List[String](length=3, fill=String(""))
    argv[0] = String("multifab_mpi_exchange")
    argv[1] = String("multifab_mpi_exchange.left_value=7")
    argv[2] = String("multifab_mpi_exchange.right_value=11")
    var runtime = AmrexRuntime(argv, use_parmparse=True)
    try:
        expect(
            runtime.nprocs() >= 2,
            "run this example with at least 2 MPI ranks",
        )

        var params = ParmParse(runtime, "multifab_mpi_exchange")
        var left_value = params.query_int("left_value")
        var right_value = params.query_int("right_value")

        var domain = box3d(
            small_end=intvect3d(0, 0, 0),
            big_end=intvect3d(DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1),
        )

        var boxarray = BoxArray(runtime, domain)
        # Force two x-slabs so the shared face is exchanged in the 2-rank example run.
        boxarray.max_size(intvect3d(SLAB_EXTENT, DOMAIN_EXTENT, DOMAIN_EXTENT))
        expect(
            boxarray.size() == 2,
            "expected a two-slab BoxArray decomposition",
        )

        var distmap = DistributionMapping(runtime, boxarray)
        var geometry = Geometry(runtime, domain)
        var source = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var destination = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))

        source.set_val(0.0)
        destination.set_val(0.0)
        expect(source.tile_count() > 0, "each rank should own at least one tile")

        var mfi = source.mfiter()
        while mfi.is_valid():
            var valid_box = mfi.validbox()
            fill_box_value(
                source.array(mfi),
                valid_box,
                slab_fill_value(valid_box, left_value, right_value),
            )
            mfi.next()

        source.fill_boundary(geometry)
        var expected_ghost = interface_expected_value(source, left_value, right_value)
        var source_ghost = interface_ghost_sample(source)
        expect_close(
            source_ghost,
            expected_ghost,
            1.0e-12,
            "fill_boundary should exchange the slab interface ghost cells",
        )
        expect(
            has_nonzero_ghost_cells(source),
            "fill_boundary should populate source ghost cells",
        )

        destination.parallel_copy_from(
            source,
            geometry,
            0,
            0,
            1,
            intvect3d(1, 1, 1),
            intvect3d(1, 1, 1),
        )
        expect(
            has_nonzero_ghost_cells(destination),
            "parallel_copy_from should populate destination ghost cells",
        )

        var expected_sum = Float64(CELLS_PER_SLAB * (left_value + right_value))
        expect_close(source.sum(0), expected_sum, 1.0e-12, "source.sum mismatch")
        expect_close(
            destination.sum(0),
            expected_sum,
            1.0e-12,
            "destination.sum mismatch",
        )

        print(
            "rank=",
            runtime.myproc(),
            " local_tiles=",
            source.tile_count(),
            " source_ghost=",
            source_ghost,
            " copied_sum=",
            destination.sum(0),
        )
        if runtime.ioprocessor():
            print("multifab_mpi_exchange: ok")
        runtime^.close()
    except e:
        runtime^.close()
        raise e^
