from amrex.space3d import (
    AmrexRuntime,
    Array4F32View,
    Array4F64View,
    Box3D,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    MultiFabF32,
    ParmParse,
    ParallelFor,
    TileF32View,
    TileF64View,
    box3d,
    intvect3d,
)
from std.os.path import exists


comptime DOMAIN_EXTENT = 64
comptime DOMAIN_CELLS = DOMAIN_EXTENT * DOMAIN_EXTENT * DOMAIN_EXTENT


@fieldwise_init
struct UpdateTileContext[
    dst_origin: Origin[mut=True],
    src_origin: Origin[mut=True],
](Copyable):
    var dst_array: Array4F64View[Self.dst_origin]
    var src_array: Array4F64View[Self.src_origin]
    var add_value: Float64


def expect(condition: Bool, message: StringLiteral) raises:
    if not condition:
        raise Error(message)


def expect_equal(
    actual: Float64, expected: Float64, message: StringLiteral
) raises:
    expect(actual == expected, message)


def box_contains(box: Box3D, i: Int, j: Int, k: Int) raises -> Bool:
    return (
        i >= Int(box.small_end.x)
        and i <= Int(box.big_end.x)
        and j >= Int(box.small_end.y)
        and j <= Int(box.big_end.y)
        and k >= Int(box.small_end.z)
        and k <= Int(box.big_end.z)
    )


def fill_box_value[
    owner_origin: Origin[mut=True]
](array: Array4F64View[owner_origin], box: Box3D, value: Float64) raises:
    for k in range(Int(box.small_end.z), Int(box.big_end.z) + 1):
        for j in range(Int(box.small_end.y), Int(box.big_end.y) + 1):
            for i in range(Int(box.small_end.x), Int(box.big_end.x) + 1):
                array[i, j, k] = value


def fill_box_value_f32[
    owner_origin: Origin[mut=True]
](array: Array4F32View[owner_origin], box: Box3D, value: Float32) raises:
    for k in range(Int(box.small_end.z), Int(box.big_end.z) + 1):
        for j in range(Int(box.small_end.y), Int(box.big_end.y) + 1):
            for i in range(Int(box.small_end.x), Int(box.big_end.x) + 1):
                array[i, j, k] = value


def has_nonzero_ghost_cells(mut multifab: MultiFab) raises -> Bool:
    var mfi = multifab.mfiter()
    while mfi.is_valid():
        var valid_box = mfi.validbox()
        var fab_box = mfi.fabbox()
        var array = multifab.array(mfi)
        for k in range(Int(fab_box.small_end.z), Int(fab_box.big_end.z) + 1):
            for j in range(
                Int(fab_box.small_end.y), Int(fab_box.big_end.y) + 1
            ):
                for i in range(
                    Int(fab_box.small_end.x), Int(fab_box.big_end.x) + 1
                ):
                    if (
                        not box_contains(valid_box, i, j, k)
                        and array[i, j, k] != 0.0
                    ):
                        return True
        mfi.next()

    return False


def fill_source_tile[
    owner_origin: Origin[mut=True]
](tile: TileF64View[owner_origin]) raises:
    tile.fill(2.0)


def fill_source_tile_f32[
    owner_origin: Origin[mut=True]
](tile: TileF32View[owner_origin]) raises:
    tile.fill(Float32(1.25))


def main() raises:
    var runtime = AmrexRuntime()
    try:
        var domain = box3d(
            small_end=intvect3d(0, 0, 0),
            big_end=intvect3d(
                DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1
            ),
        )

        var boxarray = BoxArray(runtime, domain)
        boxarray.max_size(32)

        var distmap = DistributionMapping(runtime, boxarray)
        var geometry = Geometry(runtime, domain)
        var default_multifab = MultiFab(runtime, boxarray, distmap, 1)
        var default_memory = default_multifab.memory_info()
        expect(
            default_memory.host_accessible,
            "default multifab should be host-accessible",
        )

        var source = MultiFab(
            runtime, boxarray, distmap, 1, intvect3d(1, 1, 1), host_only=True
        )
        var destination = MultiFab(
            runtime, boxarray, distmap, 1, intvect3d(1, 1, 1), host_only=True
        )
        var copy_target = MultiFab(
            runtime, boxarray, distmap, 1, intvect3d(1, 1, 1), host_only=True
        )

        expect(source.ncomp() == 1, "source should have one component")
        var ngrow = source.ngrow()
        expect(
            Int(ngrow.x) == 1 and Int(ngrow.y) == 1 and Int(ngrow.z) == 1,
            "ngrow should be (1, 1, 1)",
        )

        var params = ParmParse(runtime, "multifab_functional_test")
        params.add_int("tile_add", 3)
        expect(
            params.query_int("tile_add") == 3, "ParmParse query_int mismatch"
        )
        expect(
            params.query_int_or("missing_value", 11) == 11,
            "ParmParse query_int_or mismatch",
        )

        source.for_each_tile[fill_source_tile]()
        destination.set_val(0.0)

        var mfi = destination.mfiter()
        var iterated_tiles = 0
        while mfi.is_valid():
            var tile_box = mfi.tilebox()
            _ = mfi.validbox()
            _ = mfi.fabbox()
            _ = mfi.growntilebox()
            _ = mfi.index()
            _ = mfi.local_tile_index()

            var update_ctx = UpdateTileContext(
                dst_array=destination.array(mfi).copy(),
                src_array=source.array(mfi).copy(),
                add_value=Float64(params.query_int("tile_add")),
            )

            @parameter
            def update_tile(
                ctx: type_of(update_ctx), i: Int, j: Int, k: Int
            ) raises:
                ctx.dst_array[i, j, k] = ctx.src_array[i, j, k] + ctx.add_value

            ParallelFor[body=update_tile](tile_box, update_ctx)
            iterated_tiles += 1
            mfi.next()

        expect(
            iterated_tiles == destination.tile_count(),
            "MFIter should visit every tile",
        )

        var gpu_mfi = destination.gpu_mfiter()
        var gpu_iterated_tiles = 0
        var num_gpu_streams = runtime.gpu_num_streams()
        while gpu_mfi.is_valid():
            expect(
                gpu_mfi.stream_index() == gpu_iterated_tiles % num_gpu_streams,
                (
                    "GpuMFIter stream index should round-robin over the active"
                    " stream set"
                ),
            )
            _ = gpu_mfi.tilebox()
            _ = gpu_mfi.validbox()
            _ = gpu_mfi.fabbox()
            _ = gpu_mfi.growntilebox()
            _ = gpu_mfi.index()
            _ = gpu_mfi.local_tile_index()
            gpu_iterated_tiles += 1
            gpu_mfi.next()

        expect(
            gpu_iterated_tiles == destination.tile_count(),
            "GpuMFIter should visit every tile",
        )

        expect_equal(
            source.sum(0),
            2.0 * Float64(DOMAIN_CELLS),
            "source.sum mismatch",
        )
        expect_equal(
            destination.sum(0),
            5.0 * Float64(DOMAIN_CELLS),
            "destination.sum after MFIter update mismatch",
        )
        expect_equal(destination.min(0), 5.0, "destination.min mismatch")
        expect_equal(destination.max(0), 5.0, "destination.max mismatch")
        expect_equal(destination.norm0(0), 5.0, "destination.norm0 mismatch")

        destination.plus(1.0, 0, 1)
        expect_equal(
            destination.sum(0),
            6.0 * Float64(DOMAIN_CELLS),
            "destination.sum after plus mismatch",
        )

        destination.mult(0.5, 0, 1)
        expect_equal(
            destination.sum(0),
            3.0 * Float64(DOMAIN_CELLS),
            "destination.sum after mult mismatch",
        )
        expect_equal(
            destination.min(0), 3.0, "destination.min after mult mismatch"
        )
        expect_equal(
            destination.max(0), 3.0, "destination.max after mult mismatch"
        )
        expect_equal(
            destination.norm1(0),
            3.0 * Float64(DOMAIN_CELLS),
            "destination.norm1 mismatch",
        )

        copy_target.copy_from(destination, 0, 0, 1)
        expect_equal(
            copy_target.sum(0),
            destination.sum(0),
            "copy_target.sum mismatch",
        )

        var source_f32 = MultiFabF32(
            runtime, boxarray, distmap, 1, intvect3d(1, 1, 1), host_only=True
        )
        var destination_f32 = MultiFabF32(
            runtime, boxarray, distmap, 1, intvect3d(1, 1, 1), host_only=True
        )
        source_f32.for_each_tile[fill_source_tile_f32]()
        destination_f32.set_val(Float32(0.0))
        destination_f32.copy_from(source_f32, 0, 0, 1)
        expect_equal(
            destination_f32.sum(0),
            1.25 * Float64(DOMAIN_CELLS),
            "destination_f32.sum after copy_from mismatch",
        )

        var mfi_f32 = destination_f32.mfiter()
        while mfi_f32.is_valid():
            var tile_box_f32 = mfi_f32.tilebox()
            var dst_array_f32 = destination_f32.array(mfi_f32)
            var src_array_f32 = source_f32.array(mfi_f32)
            for k in range(
                Int(tile_box_f32.small_end.z), Int(tile_box_f32.big_end.z) + 1
            ):
                for j in range(
                    Int(tile_box_f32.small_end.y),
                    Int(tile_box_f32.big_end.y) + 1,
                ):
                    for i in range(
                        Int(tile_box_f32.small_end.x),
                        Int(tile_box_f32.big_end.x) + 1,
                    ):
                        dst_array_f32[i, j, k] = src_array_f32[
                            i, j, k
                        ] + Float32(0.5)
            mfi_f32.next()

        expect_equal(
            destination_f32.sum(0),
            1.75 * Float64(DOMAIN_CELLS),
            "destination_f32.sum after MFIter update mismatch",
        )
        destination_f32.plus(Float32(0.25), 0, 1)
        expect_equal(
            destination_f32.max(0),
            2.0,
            "destination_f32.max after plus mismatch",
        )
        var plotfile_path_f32 = String(
            "build/multifab_functional_test_plotfile_f32"
        )
        destination_f32.write_single_level_plotfile(plotfile_path_f32, geometry)
        expect(
            exists(plotfile_path_f32 + "/Header"),
            "Float32 plotfile Header was not written",
        )

        var comm_source = MultiFab(
            runtime, boxarray, distmap, 1, intvect3d(1, 1, 1), host_only=True
        )
        var comm_destination = MultiFab(
            runtime, boxarray, distmap, 1, intvect3d(1, 1, 1), host_only=True
        )
        comm_source.set_val(0.0)
        comm_destination.set_val(0.0)

        var comm_mfi = comm_source.mfiter()
        var rank_value = Float64(runtime.myproc() + 1)
        while comm_mfi.is_valid():
            fill_box_value(
                comm_source.array(comm_mfi), comm_mfi.tilebox(), rank_value
            )
            comm_mfi.next()

        expect(
            not has_nonzero_ghost_cells(comm_source),
            "comm_source ghosts should start at zero",
        )
        comm_source.fill_boundary(geometry)
        expect(
            has_nonzero_ghost_cells(comm_source),
            "fill_boundary should populate ghost cells",
        )

        comm_destination.parallel_copy_from(
            comm_source,
            geometry,
            0,
            0,
            1,
            intvect3d(0, 0, 0),
            intvect3d(1, 1, 1),
        )
        expect_equal(
            comm_destination.sum(0),
            comm_source.sum(0),
            "parallel_copy_from should preserve the valid-region sum",
        )
        expect(
            has_nonzero_ghost_cells(comm_destination),
            "parallel_copy_from should populate destination ghost cells",
        )

        var plotfile_path = String("build/multifab_functional_test_plotfile")
        destination.write_single_level_plotfile(plotfile_path, geometry)
        expect(
            exists(plotfile_path + "/Header"),
            "plotfile Header was not written",
        )

        print("multifab_functional_test: ok")
        runtime^.close()
    except e:
        runtime^.close()
        raise e^
