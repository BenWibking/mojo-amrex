# ABOUTME: Functional tests for MultiFab operations and MFIter traversal.
# ABOUTME: Covers reductions, copies, type variants, and plotfile output.

from amrex.space3d import (
    AmrexFloat32,
    AmrexFloat64,
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParmInt,
    ParmParse,
    box3d,
    convert,
    intvect3d,
)
from std.math import abs
from std.os.path import exists
from std.testing import assert_equal, assert_true


comptime DOMAIN_EXTENT = 64
comptime DOMAIN_CELLS = DOMAIN_EXTENT * DOMAIN_EXTENT * DOMAIN_EXTENT


def main() raises:
    var runtime = AmrexRuntime()
    try:
        var domain = box3d(
            small_end=intvect3d(0, 0, 0),
            big_end=intvect3d(DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1),
        )

        var boxarray = BoxArray(runtime, domain)
        boxarray.max_size(32)
        var original_box = boxarray.box(0)

        var xface_boxarray = convert(boxarray, intvect3d(1, 0, 0))
        var xface_box = xface_boxarray.box(0)
        assert_true(
            Int(original_box.nodal.x) == 0 and Int(original_box.nodal.y) == 0 and Int(original_box.nodal.z) == 0,
            "convert helper should not mutate the source BoxArray",
        )
        assert_true(
            Int(xface_box.nodal.x) == 1 and Int(xface_box.nodal.y) == 0 and Int(xface_box.nodal.z) == 0,
            "convert helper should make an x-face-centered BoxArray",
        )
        assert_true(
            Int(xface_box.small_end.x) == Int(original_box.small_end.x)
            and Int(xface_box.big_end.x) == Int(original_box.big_end.x) + 1,
            "x-face-centered BoxArray should extend one node past the cell-centered high x face",
        )

        var yface_boxarray = BoxArray(runtime, domain)
        yface_boxarray.max_size(32)
        yface_boxarray.surrounding_nodes(1)
        var yface_box = yface_boxarray.box(0)
        assert_true(
            Int(yface_box.nodal.x) == 0 and Int(yface_box.nodal.y) == 1 and Int(yface_box.nodal.z) == 0,
            "surrounding_nodes(dir) should make a face-centered BoxArray",
        )

        var nodal_boxarray = BoxArray(runtime, domain)
        nodal_boxarray.max_size(32)
        nodal_boxarray.surrounding_nodes()
        var nodal_box = nodal_boxarray.box(0)
        assert_true(
            Int(nodal_box.nodal.x) == 1 and Int(nodal_box.nodal.y) == 1 and Int(nodal_box.nodal.z) == 1,
            "surrounding_nodes() should make a node-centered BoxArray",
        )

        var distmap = DistributionMapping(runtime, boxarray)
        var xface_distmap = DistributionMapping(runtime, xface_boxarray)
        var geometry = Geometry(runtime, domain)
        var default_multifab = MultiFab[AmrexFloat64](runtime, boxarray, distmap, 1)
        var xface_multifab = MultiFab[AmrexFloat64](runtime, xface_boxarray, xface_distmap, 1)
        var xface_valid_box = xface_multifab.valid_box(0)
        assert_true(
            Int(xface_valid_box.nodal.x) == 1
            and Int(xface_valid_box.nodal.y) == 0
            and Int(xface_valid_box.nodal.z) == 0,
            "face-centered MultiFab should preserve BoxArray centering",
        )
        var default_memory = default_multifab.memory_info()
        assert_true(
            default_memory.host_accessible or default_memory.device_accessible,
            "default multifab should expose host or device storage",
        )

        var source = MultiFab[AmrexFloat64](runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var destination = MultiFab[AmrexFloat64](runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var copy_target = MultiFab[AmrexFloat64](runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))

        assert_true(source.ncomp() == 1, "source should have one component")
        var ngrow = source.ngrow()
        assert_true(
            Int(ngrow.x) == 1 and Int(ngrow.y) == 1 and Int(ngrow.z) == 1,
            "ngrow should be (1, 1, 1)",
        )

        var params = ParmParse(runtime, "multifab_functional_test")
        params.add[ParmInt]("tile_add", 3)
        assert_true(
            params.query[ParmInt]("tile_add") == 3,
            "ParmParse query_int mismatch",
        )
        assert_true(
            params.query_or[ParmInt]("missing_value", 11) == 11,
            "ParmParse query_int_or mismatch",
        )

        source.set_val(2.0)
        destination.set_val(0.0)

        var mfi = destination.mfiter()
        var iterated_tiles = 0
        for tile in mfi:
            var tile_box = tile.tile_box
            _ = tile.valid_box
            _ = tile.fab_box
            _ = mfi.growntilebox()
            _ = mfi.index()
            _ = mfi.local_tile_index()
            var dst_array = destination.array(mfi)
            var src_array = source.array(mfi)
            var add_value: Float64 = Float64(params.query[ParmInt]("tile_add"))

            def add_cell(i: Int, j: Int, k: Int) {var dst_array^, var src_array^, var add_value}:
                dst_array[i, j, k] = src_array[i, j, k] + add_value

            mfi.parallel_for(add_cell, tile_box)
            iterated_tiles += 1

        assert_true(
            iterated_tiles == destination.tile_count(),
            "MFIter should visit every tile",
        )

        var for_iterated_tiles = 0
        for tile in destination.tiles():
            assert_true(
                tile.index >= 0,
                "MFIter iterator tile index should be non-negative",
            )
            assert_true(
                tile.local_tile_index >= 0,
                "MFIter iterator local tile index should be non-negative",
            )
            assert_true(
                tile.tile_box.small_end.x <= tile.tile_box.big_end.x,
                "MFIter iterator should expose a valid tile box",
            )
            for_iterated_tiles += 1

        assert_true(
            for_iterated_tiles == destination.tile_count(),
            "MFIter iterator should visit every tile",
        )

        if runtime.gpu_backend() != "none" and default_memory.device_accessible:
            var gpu_mfi = default_multifab.mfiter()
            var gpu_iterated_tiles = 0
            var num_gpu_streams = runtime.gpu_num_streams()
            for tile in gpu_mfi:
                assert_true(
                    gpu_mfi.stream_index() == gpu_iterated_tiles % num_gpu_streams,
                    "MFIter stream index should round-robin over the active stream set",
                )
                _ = tile.tile_box
                _ = tile.valid_box
                _ = tile.fab_box
                _ = gpu_mfi.growntilebox()
                _ = gpu_mfi.index()
                _ = gpu_mfi.local_tile_index()
                gpu_iterated_tiles += 1

            assert_true(
                gpu_iterated_tiles == default_multifab.tile_count(),
                "MFIter should visit every tile",
            )

        assert_equal(
            source.sum(0),
            2.0 * Float64(DOMAIN_CELLS),
            "source.sum mismatch",
        )
        assert_equal(
            destination.sum(0),
            5.0 * Float64(DOMAIN_CELLS),
            "destination.sum after MFIter update mismatch",
        )
        assert_equal(destination.min(0), 5.0, "destination.min mismatch")
        assert_equal(destination.max(0), 5.0, "destination.max mismatch")
        assert_equal(destination.norm0(0), 5.0, "destination.norm0 mismatch")

        destination.plus(1.0, 0, 1)
        assert_equal(
            destination.sum(0),
            6.0 * Float64(DOMAIN_CELLS),
            "destination.sum after plus mismatch",
        )

        destination.mult(0.5, 0, 1)
        assert_equal(
            destination.sum(0),
            3.0 * Float64(DOMAIN_CELLS),
            "destination.sum after mult mismatch",
        )
        assert_equal(destination.min(0), 3.0, "destination.min after mult mismatch")
        assert_equal(destination.max(0), 3.0, "destination.max after mult mismatch")
        assert_equal(
            destination.norm1(0),
            3.0 * Float64(DOMAIN_CELLS),
            "destination.norm1 mismatch",
        )
        copy_target.copy_from(destination, 0, 0, 1)
        assert_equal(
            copy_target.sum(0),
            destination.sum(0),
            "copy_target.sum mismatch",
        )

        var source_f32 = MultiFab[AmrexFloat32](runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var destination_f32 = MultiFab[AmrexFloat32](runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        source_f32.set_val(Float32(1.25))
        destination_f32.set_val(Float32(0.0))
        destination_f32.copy_from(source_f32, 0, 0, 1)
        assert_equal(
            destination_f32.sum(0),
            1.25 * Float64(DOMAIN_CELLS),
            "destination_f32.sum after copy_from mismatch",
        )

        var mfi_f32 = destination_f32.mfiter()
        for tile in mfi_f32:
            var tile_box_f32 = tile.tile_box
            var dst_array_f32 = destination_f32.array(mfi_f32)
            var src_array_f32 = source_f32.array(mfi_f32)

            def add_cell_f32(i: Int, j: Int, k: Int) {var dst_array_f32^, var src_array_f32^}:
                dst_array_f32[i, j, k] = src_array_f32[i, j, k] + Float32(0.5)

            mfi_f32.parallel_for(add_cell_f32, tile_box_f32)

        assert_equal(
            destination_f32.sum(0),
            1.75 * Float64(DOMAIN_CELLS),
            "destination_f32.sum after MFIter update mismatch",
        )
        destination_f32.plus(Float32(0.25), 0, 1)
        assert_equal(
            destination_f32.max(0),
            2.0,
            "destination_f32.max after plus mismatch",
        )
        var plotfile_path_f32 = String("build/multifab_functional_test_plotfile_f32")
        destination_f32.write_single_level_plotfile(plotfile_path_f32, geometry)
        assert_true(
            exists(plotfile_path_f32 + "/Header"),
            "Float32 plotfile Header was not written",
        )

        var comm_source = MultiFab[AmrexFloat64](runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var comm_destination = MultiFab[AmrexFloat64](runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        comm_source.set_val(0.0)
        comm_destination.set_val(0.0)

        var comm_mfi = comm_source.mfiter()
        var rank_value = Float64(runtime.myproc() + 1)
        for tile in comm_mfi:
            var comm_array = comm_source.array(comm_mfi)
            var comm_tile_box = tile.tile_box

            def fill_rank_cell(i: Int, j: Int, k: Int) {var comm_array^, var rank_value}:
                comm_array[i, j, k] = rank_value

            comm_mfi.parallel_for(fill_rank_cell, comm_tile_box)

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
        assert_equal(
            comm_destination.sum(0),
            comm_source.sum(0),
            "parallel_copy_from should preserve the valid-region sum",
        )

        var plotfile_path = String("build/multifab_functional_test_plotfile")
        destination.write_single_level_plotfile(plotfile_path, geometry)
        assert_true(
            exists(plotfile_path + "/Header"),
            "plotfile Header was not written",
        )

        print("multifab_functional_test: ok")
        runtime^.close()
    except e:
        runtime^.close()
        raise e^
