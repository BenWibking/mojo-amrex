from amrex.space3d import (
    AmrexRuntime,
    Array4F64View,
    BoxArray,
    DistributionMapping,
    Geometry,
    MultiFab,
    ParallelFor,
    ParmParse,
    TileF64View,
    box3d,
    intvect3d,
)


@fieldwise_init
struct UpdateTileContext[
    dst_origin: Origin[mut=True],
    src_origin: Origin[mut=True],
](Copyable):
    var dst_array: Array4F64View[Self.dst_origin]
    var src_array: Array4F64View[Self.src_origin]
    var fill_value: Int


fn fill_tile[
    owner_origin: Origin[mut=True]
](tile: TileF64View[owner_origin]) raises:
    tile.fill(1.0)


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
    var source = MultiFab(runtime, boxarray, distmap, 1, intvect3d(1, 1, 1))
    var parmparse_prefix = String("multifab_smoke")
    var tile_fill_name = String("tile_fill_value")
    var plotfile_path = String("build/multifab_smoke_plotfile")
    var params = ParmParse(runtime, parmparse_prefix)
    params.add_int(tile_fill_name, 42)

    if domain_box.big_end.x != 63 or first_box.big_end.x != 31:
        raise Error("unexpected geometry or boxarray bounds")
    if prob_domain.hi_x != 1.0 or cell_size.x != (1.0 / 64.0):
        raise Error("unexpected geometry metrics")
    if periodicity.x != 0 or periodicity.y != 0 or periodicity.z != 0:
        raise Error("unexpected geometry periodicity")

    var fill_value = params.query_int(tile_fill_name)
    if fill_value != 42:
        raise Error("unexpected tile_fill_value in ParmParse")

    source.for_each_tile[fill_tile]()
    multifab.set_val(0.0)

    var mfi = multifab.mfiter()
    while mfi.is_valid():
        var tile_box = mfi.tilebox()
        var valid_box = mfi.validbox()
        var fab_box = mfi.fabbox()
        var grown_box = mfi.growntilebox()
        if mfi.index() < 0 or mfi.local_tile_index() < 0:
            raise Error("unexpected MFIter index state")
        if tile_box.small_end.x < valid_box.small_end.x:
            raise Error("tile box extends below valid box")
        if grown_box.small_end.x < fab_box.small_end.x:
            raise Error("grown tile box extends below FAB box")

        var dst_array = multifab.array(mfi)
        var src_array = source.array(mfi)
        var update_ctx = UpdateTileContext(
            dst_array=dst_array.copy(),
            src_array=src_array.copy(),
            fill_value=fill_value,
        )

        @parameter
        fn update_tile(ctx: type_of(update_ctx), i: Int, j: Int, k: Int):
            ctx.dst_array.store(
                i,
                j,
                k,
                ctx.src_array.load(i, j, k) + Float64(ctx.fill_value - 1),
            )

        ParallelFor[body=update_tile](tile_box, update_ctx)
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
