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
    if boxarray.size() != 8:
        raise Error("unexpected BoxArray size")
    var first_box = boxarray.box(0)

    var distmap = DistributionMapping(runtime, boxarray)
    var geometry = Geometry(runtime, domain)
    var domain_box = geometry.domain()
    var prob_domain = geometry.prob_domain()
    var cell_size = geometry.cell_size()
    var periodicity = geometry.periodicity()
    var multifab = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
    var params = ParmParse(runtime, "multifab_smoke")
    params.add_int("tile_fill_value", 42)

    if domain_box.big_end.x != 63 or first_box.big_end.x != 31:
        raise Error("unexpected geometry or boxarray bounds")
    if prob_domain.hi_x != 1.0 or cell_size.x != (1.0 / 64.0):
        raise Error("unexpected geometry metrics")
    if periodicity.x != 0 or periodicity.y != 0 or periodicity.z != 0:
        raise Error("unexpected geometry periodicity")

    var fill_value = params.query_int("tile_fill_value")
    if fill_value != 42:
        raise Error("unexpected tile_fill_value in ParmParse")
    multifab.for_each_tile[fill_tile]()

    var ntile = multifab.tile_count()
    multifab.write_single_level_plotfile(
        "build/multifab_smoke_plotfile",
        geometry,
    )

    print("boxes=", boxarray.size())
    print("nprocs=", runtime.nprocs())
    print("tiles=", ntile)
    print("sum=", multifab.sum(0))
