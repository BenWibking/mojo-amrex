from amrex.space3d import (
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParmParse,
    TileF64View,
    box3d,
    intvect3d,
    ParallelFor,
)


def fill_tile[owner_origin: Origin[mut=True]](tile: TileF64View[owner_origin]) raises:
    tile.fill(1.0)


def main() raises:
    var runtime = AmrexRuntime()
    try:
        var domain = box3d(
            small_end=intvect3d(0, 0, 0),
            big_end=intvect3d(63, 63, 63),
        )

        var boxarray = BoxArray(runtime, domain)
        boxarray.max_size(32)

        var distmap = DistributionMapping(runtime, boxarray)
        var geometry = Geometry(runtime, domain)
        var domain_box = geometry.domain()
        var prob_domain = geometry.prob_domain()
        var cell_size = geometry.cell_size()
        var periodicity = geometry.periodicity()
        var multifab = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
        var source = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))

        var parmparse_prefix = String("multifab_smoke")
        var tile_fill_name = String("tile_fill_value")
        var plotfile_path = String("build/multifab_smoke_plotfile")
        var params = ParmParse(runtime, parmparse_prefix)
        params.add_int(tile_fill_name, 42)

        var fill_value = params.query_int(tile_fill_name)
        source.for_each_tile[fill_tile]()
        multifab.set_val(0.0)

        var mfi = multifab.mfiter()
        while mfi.is_valid():
            var tile_box = mfi.tilebox()
            var valid_box = mfi.validbox()
            var fab_box = mfi.fabbox()
            var grown_box = mfi.growntilebox()
            var dst_array = multifab.array(mfi)
            var src_array = source.array(mfi)

            def update_tile(i: Int, j: Int, k: Int) raises {var dst_array^, var src_array^, var fill_value}:
                dst_array[i, j, k] = src_array[i, j, k] + Float64(fill_value - 1)

            ParallelFor(update_tile, tile_box)
            mfi.next()

        var ntile = multifab.tile_count()
        multifab.write_single_level_plotfile(
            plotfile_path,
            geometry,
        )

        print("boxes=", boxarray.size())
        print("nprocs=", runtime.nprocs())
        print("tiles=", ntile)
        print("sum=", multifab.sum(0))
        runtime^.close()
    except e:
        runtime^.close()
        raise e^
