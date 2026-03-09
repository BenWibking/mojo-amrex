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
)


fn fill_tile(tile: TileF64View) raises:
    tile.fill(42.0)


fn main() raises:
    var runtime = AmrexRuntime()

    var domain = box3d(
        small_end=intvect3d(0, 0, 0),
        big_end=intvect3d(63, 63, 63),
    )

    var boxarray = BoxArray(runtime, domain)
    boxarray.max_size(32)

    var distmap = DistributionMapping(runtime, boxarray)
    var geometry = Geometry(runtime, domain)
    var multifab = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
    var params = ParmParse(runtime, "multifab_smoke")
    params.add_int("tile_fill_value", 42)

    var fill_value = params.query_int("tile_fill_value")
    if fill_value != 42:
        raise Error("unexpected tile_fill_value in ParmParse")
    multifab.for_each_tile[fill_tile]()

    var ntile = multifab.tile_count()
    multifab.write_single_level_plotfile(
        "multifab_smoke_plt",
        geometry,
    )

    print("nprocs=", runtime.nprocs())
    print("tiles=", ntile)
    print("sum=", multifab.sum(0))
