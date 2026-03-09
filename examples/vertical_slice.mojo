from amrex.loader import load_default_library
from amrex.space3d import (
    box3d,
    boxarray_create_from_box,
    boxarray_destroy,
    boxarray_max_size,
    distmap_create_from_boxarray,
    distmap_destroy,
    geometry_create,
    geometry_destroy,
    intvect3d,
    multifab_create,
    multifab_destroy,
    multifab_sum,
    multifab_tile_count,
    parallel_nprocs,
    runtime_create,
    runtime_destroy,
    tile_view,
)


fn main() raises:
    var lib = load_default_library()
    var runtime = runtime_create(lib)

    var domain = box3d(
        small_end=intvect3d(0, 0, 0),
        big_end=intvect3d(63, 63, 63),
    )

    var boxarray = boxarray_create_from_box(lib, runtime, domain)
    _ = boxarray_max_size(lib, boxarray, intvect3d(32, 32, 32))

    var distmap = distmap_create_from_boxarray(lib, runtime, boxarray)
    var geometry = geometry_create(lib, runtime, domain)
    var multifab = multifab_create(lib, runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))

    var ntile = multifab_tile_count(lib, multifab)
    for tile_index in range(ntile):
        var tile = tile_view(lib, multifab, tile_index)
        tile.fill(42.0)

    print("nprocs=", parallel_nprocs(lib))
    print("tiles=", ntile)
    print("sum=", multifab_sum(lib, multifab, 0))

    multifab_destroy(lib, multifab)
    geometry_destroy(lib, geometry)
    distmap_destroy(lib, distmap)
    boxarray_destroy(lib, boxarray)
    runtime_destroy(lib, runtime)
