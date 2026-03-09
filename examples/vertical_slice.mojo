from amrex.space3d import (
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    box3d,
    intvect3d,
)


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

    var ntile = multifab.tile_count()
    for tile_index in range(ntile):
        var tile = multifab.tile(tile_index)
        tile.fill(42.0)

    print("nprocs=", runtime.nprocs())
    print("tiles=", ntile)
    print("sum=", multifab.sum(0))
