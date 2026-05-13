from amrex.space3d import (
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    MultiFabF32,
    ParmParse,
    box3d,
    intvect3d,
)
from std.os.path import exists


comptime DOMAIN_EXTENT = 64
comptime DOMAIN_CELLS = DOMAIN_EXTENT * DOMAIN_EXTENT * DOMAIN_EXTENT


def expect(condition: Bool, message: StringLiteral) raises:
    if not condition:
        raise Error(message)


def expect_equal(actual: Float64, expected: Float64, message: StringLiteral) raises:
    expect(actual == expected, message)


def main() raises:
    var runtime = AmrexRuntime()
    try:
        var domain = box3d(
            small_end=intvect3d(0, 0, 0),
            big_end=intvect3d(DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1),
        )

        var boxarray = BoxArray(runtime, domain)
        boxarray.max_size(32)

        var distmap = DistributionMapping(runtime, boxarray)
        var geometry = Geometry(runtime, domain)
        var default_multifab = MultiFab(runtime, boxarray, distmap, 1)
        var default_memory = default_multifab.memory_info()
        expect(
            default_memory.host_accessible or default_memory.device_accessible,
            "default multifab should expose host or device storage",
        )

        var source = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var destination = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var copy_target = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))

        expect(source.ncomp() == 1, "source should have one component")
        var ngrow = source.ngrow()
        expect(
            Int(ngrow.x) == 1 and Int(ngrow.y) == 1 and Int(ngrow.z) == 1,
            "ngrow should be (1, 1, 1)",
        )

        var params = ParmParse(runtime, "multifab_functional_test")
        params.add_int("tile_add", 3)
        expect(params.query_int("tile_add") == 3, "ParmParse query_int mismatch")
        expect(
            params.query_int_or("missing_value", 11) == 11,
            "ParmParse query_int_or mismatch",
        )

        source.set_val(2.0)
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
            var dst_array = destination.array(mfi)
            var src_array = source.array(mfi)
            var add_value = Float64(params.query_int("tile_add"))

            def add_cell(i: Int, j: Int, k: Int) register_passable {var dst_array^, var src_array^, var add_value}:
                dst_array[i, j, k] = src_array[i, j, k] + add_value

            mfi.parallel_for(add_cell, tile_box)
            iterated_tiles += 1
            mfi.next()

        expect(
            iterated_tiles == destination.tile_count(),
            "MFIter should visit every tile",
        )

        if runtime.gpu_backend() != "none" and default_memory.device_accessible:
            var gpu_mfi = default_multifab.mfiter()
            var gpu_iterated_tiles = 0
            var num_gpu_streams = runtime.gpu_num_streams()
            while gpu_mfi.is_valid():
                expect(
                    gpu_mfi.stream_index() == gpu_iterated_tiles % num_gpu_streams,
                    "MFIter stream index should round-robin over the active stream set",
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
                gpu_iterated_tiles == default_multifab.tile_count(),
                "MFIter should visit every tile",
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
        expect_equal(destination.min(0), 3.0, "destination.min after mult mismatch")
        expect_equal(destination.max(0), 3.0, "destination.max after mult mismatch")
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

        var source_f32 = MultiFabF32(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var destination_f32 = MultiFabF32(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        source_f32.set_val(Float32(1.25))
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

            def add_cell_f32(i: Int, j: Int, k: Int) register_passable {var dst_array_f32^, var src_array_f32^}:
                dst_array_f32[i, j, k] = src_array_f32[i, j, k] + Float32(0.5)

            mfi_f32.parallel_for(add_cell_f32, tile_box_f32)
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
        var plotfile_path_f32 = String("build/multifab_functional_test_plotfile_f32")
        destination_f32.write_single_level_plotfile(plotfile_path_f32, geometry)
        expect(
            exists(plotfile_path_f32 + "/Header"),
            "Float32 plotfile Header was not written",
        )

        var comm_source = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var comm_destination = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        comm_source.set_val(0.0)
        comm_destination.set_val(0.0)

        var comm_mfi = comm_source.mfiter()
        var rank_value = Float64(runtime.myproc() + 1)
        while comm_mfi.is_valid():
            var comm_array = comm_source.array(comm_mfi)
            var comm_tile_box = comm_mfi.tilebox()

            def fill_rank_cell(i: Int, j: Int, k: Int) register_passable {var comm_array^, var rank_value}:
                comm_array[i, j, k] = rank_value

            comm_mfi.parallel_for(fill_rank_cell, comm_tile_box)
            comm_mfi.next()

        comm_source.fill_boundary(geometry)

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
