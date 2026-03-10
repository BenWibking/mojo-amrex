from amrex.space3d import (
    AmrexRuntime,
    Array4F64View,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParmParse,
    ParallelFor,
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


def fill_source_tile[
    owner_origin: Origin[mut=True]
](tile: TileF64View[owner_origin]) raises:
    tile.fill(2.0)


def main() raises:
    var runtime = AmrexRuntime()
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
    var source = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
    var destination = MultiFab(
        runtime, boxarray, distmap, 1, intvect3d(1, 1, 1)
    )
    var copy_target = MultiFab(
        runtime, boxarray, distmap, 1, intvect3d(1, 1, 1)
    )

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

    var plotfile_path = String("build/multifab_functional_test_plotfile")
    destination.write_single_level_plotfile(plotfile_path, geometry)
    expect(
        exists(plotfile_path + "/Header"),
        "plotfile Header was not written",
    )

    print("multifab_functional_test: ok")
