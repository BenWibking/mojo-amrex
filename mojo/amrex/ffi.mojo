from std.collections import List
from std.ffi import OwnedDLHandle, c_char, c_double, c_int


comptime RuntimeHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime BoxArrayHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime DistributionMappingHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime GeometryHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime MultiFabHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime MFIterHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime ParmParseHandle = UnsafePointer[NoneType, MutExternalOrigin]


@fieldwise_init
struct IntVect3D(Copyable):
    var x: c_int
    var y: c_int
    var z: c_int


@fieldwise_init
struct Box3D(Copyable):
    var small_end: IntVect3D
    var big_end: IntVect3D
    var nodal: IntVect3D


@fieldwise_init
struct RealBox3D(Copyable):
    var lo_x: Float64
    var lo_y: Float64
    var lo_z: Float64
    var hi_x: Float64
    var hi_y: Float64
    var hi_z: Float64


@fieldwise_init
struct RealVect3D(Copyable):
    var x: Float64
    var y: Float64
    var z: Float64


@fieldwise_init
struct ParmParseIntQueryResult(Copyable):
    var status: Int
    var found: Bool
    var value: Int


@fieldwise_init
struct Box3DResult(Copyable):
    var status: Int
    var value: Box3D


@fieldwise_init
struct RealBox3DResult(Copyable):
    var status: Int
    var value: RealBox3D


@fieldwise_init
struct RealVect3DResult(Copyable):
    var status: Int
    var value: RealVect3D


@fieldwise_init
struct IntVect3DResult(Copyable):
    var status: Int
    var value: IntVect3D


@fieldwise_init
struct Array4F64View[origin: Origin[mut=True]](Copyable):
    var data: UnsafePointer[c_double, Self.origin]
    var lo_x: c_int
    var lo_y: c_int
    var lo_z: c_int
    var hi_x: c_int
    var hi_y: c_int
    var hi_z: c_int
    var stride_i: Int64
    var stride_j: Int64
    var stride_k: Int64
    var stride_n: Int64
    var ncomp: c_int

    def offset(self, i: Int, j: Int, k: Int, comp: Int = 0) raises -> Int:
        return (
            (i - Int(self.lo_x)) * Int(self.stride_i)
            + (j - Int(self.lo_y)) * Int(self.stride_j)
            + (k - Int(self.lo_z)) * Int(self.stride_k)
            + comp * Int(self.stride_n)
        )

    def load(self, i: Int, j: Int, k: Int, comp: Int = 0) raises -> Float64:
        return self.data[self.offset(i, j, k, comp)]

    def store(self, i: Int, j: Int, k: Int, value: Float64, comp: Int = 0) raises:
        self.data[self.offset(i, j, k, comp)] = value

    def fill(self, box: Box3D, value: Float64, comp: Int = 0) raises:
        for k in range(Int(box.small_end.z), Int(box.big_end.z) + 1):
            for j in range(Int(box.small_end.y), Int(box.big_end.y) + 1):
                for i in range(Int(box.small_end.x), Int(box.big_end.x) + 1):
                    self.store(i, j, k, value, comp)


@fieldwise_init
struct TileF64View[origin: Origin[mut=True]](Copyable):
    var tile_box: Box3D
    var valid_box: Box3D
    var array_view: Array4F64View[Self.origin]

    def array(self) raises -> Array4F64View[Self.origin]:
        return self.array_view.copy()

    def fill(self, value: Float64, comp: Int = 0) raises:
        self.array_view.fill(self.tile_box, value, comp)


def intvect3d(x: Int, y: Int, z: Int) raises -> IntVect3D:
    return IntVect3D(x=c_int(x), y=c_int(y), z=c_int(z))


def zero_intvect3d() raises -> IntVect3D:
    return intvect3d(0, 0, 0)


def box3d(
    small_end: IntVect3D,
    big_end: IntVect3D,
    nodal: IntVect3D = IntVect3D(x=0, y=0, z=0),
) raises -> Box3D:
    return Box3D(
        small_end=small_end.copy(),
        big_end=big_end.copy(),
        nodal=nodal.copy(),
    )


def last_error_message(ref lib: OwnedDLHandle) raises -> String:
    var message = lib.call[
        "amrex_mojo_last_error_message",
        UnsafePointer[c_char, ImmutExternalOrigin],
    ]()
    if not message:
        return String("AMReX call failed.")
    return String(unsafe_from_utf8_ptr=message)


def abi_version(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_abi_version", c_int]())


def runtime_create(ref lib: OwnedDLHandle) raises -> RuntimeHandle:
    return lib.call["amrex_mojo_runtime_create_default", RuntimeHandle]()


def runtime_destroy(ref lib: OwnedDLHandle, runtime: RuntimeHandle) raises:
    lib.call["amrex_mojo_runtime_destroy"](runtime)


def runtime_initialized(ref lib: OwnedDLHandle, runtime: RuntimeHandle) raises -> Bool:
    return lib.call["amrex_mojo_runtime_initialized", c_int](runtime) != 0


def parallel_nprocs(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_parallel_nprocs", c_int]())


def parallel_myproc(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_parallel_myproc", c_int]())


def parallel_ioprocessor(ref lib: OwnedDLHandle) raises -> Bool:
    return lib.call["amrex_mojo_parallel_ioprocessor", c_int]() != 0


def parallel_ioprocessor_number(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_parallel_ioprocessor_number", c_int]())


def boxarray_create_from_box(
    ref lib: OwnedDLHandle, runtime: RuntimeHandle, domain: Box3D
) raises -> BoxArrayHandle:
    return lib.call["amrex_mojo_boxarray_create_from_bounds", BoxArrayHandle](
        runtime,
        domain.small_end.x,
        domain.small_end.y,
        domain.small_end.z,
        domain.big_end.x,
        domain.big_end.y,
        domain.big_end.z,
        domain.nodal.x,
        domain.nodal.y,
        domain.nodal.z,
    )


def boxarray_destroy(ref lib: OwnedDLHandle, boxarray: BoxArrayHandle) raises:
    lib.call["amrex_mojo_boxarray_destroy"](boxarray)


def boxarray_max_size(
    ref lib: OwnedDLHandle, boxarray: BoxArrayHandle, max_size: IntVect3D
) raises -> Int:
    return Int(
        lib.call["amrex_mojo_boxarray_max_size_xyz", c_int](
            boxarray, max_size.x, max_size.y, max_size.z
        )
    )


def boxarray_size(ref lib: OwnedDLHandle, boxarray: BoxArrayHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_boxarray_size", c_int](boxarray))


def distmap_create_from_boxarray(
    ref lib: OwnedDLHandle,
    runtime: RuntimeHandle,
    boxarray: BoxArrayHandle,
) raises -> DistributionMappingHandle:
    return lib.call[
        "amrex_mojo_distmap_create_from_boxarray", DistributionMappingHandle
    ](runtime, boxarray)


def distmap_destroy(ref lib: OwnedDLHandle, distmap: DistributionMappingHandle) raises:
    lib.call["amrex_mojo_distmap_destroy"](distmap)


def geometry_create(
    ref lib: OwnedDLHandle, runtime: RuntimeHandle, domain: Box3D
) raises -> GeometryHandle:
    return lib.call["amrex_mojo_geometry_create_from_bounds", GeometryHandle](
        runtime,
        domain.small_end.x,
        domain.small_end.y,
        domain.small_end.z,
        domain.big_end.x,
        domain.big_end.y,
        domain.big_end.z,
        domain.nodal.x,
        domain.nodal.y,
        domain.nodal.z,
    )


def geometry_destroy(ref lib: OwnedDLHandle, geometry: GeometryHandle) raises:
    lib.call["amrex_mojo_geometry_destroy"](geometry)


def multifab_create(
    ref lib: OwnedDLHandle,
    runtime: RuntimeHandle,
    boxarray: BoxArrayHandle,
    distmap: DistributionMappingHandle,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> MultiFabHandle:
    return lib.call["amrex_mojo_multifab_create_xyz", MultiFabHandle](
        runtime,
        boxarray,
        distmap,
        c_int(ncomp),
        ngrow.x,
        ngrow.y,
        ngrow.z,
    )


def multifab_destroy(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises:
    lib.call["amrex_mojo_multifab_destroy"](multifab)


def multifab_ncomp(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_multifab_ncomp", c_int](multifab))


def multifab_set_val(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
) raises -> Int:
    return Int(
        lib.call["amrex_mojo_multifab_set_val", c_int](
            multifab, c_double(value), c_int(start_comp), c_int(ncomp)
        )
    )


def multifab_tile_count(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_multifab_tile_count", c_int](multifab))


def mfiter_create(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises -> MFIterHandle:
    var out_handle = List[MFIterHandle](length=1, fill=MFIterHandle())
    _ = lib.call["amrex_mojo_mfiter_create", c_int](
        multifab,
        out_handle.unsafe_ptr(),
    )
    return out_handle[0]


def mfiter_destroy(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises:
    lib.call["amrex_mojo_mfiter_destroy"](mfiter)


def mfiter_is_valid(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises -> Bool:
    return lib.call["amrex_mojo_mfiter_is_valid", c_int](mfiter) != 0


def mfiter_next(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_mfiter_next", c_int](mfiter))


def mfiter_index(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_mfiter_index", c_int](mfiter))


def mfiter_local_tile_index(
    ref lib: OwnedDLHandle, mfiter: MFIterHandle
) raises -> Int:
    return Int(lib.call["amrex_mojo_mfiter_local_tile_index", c_int](mfiter))


def mfiter_tile_box(
    ref lib: OwnedDLHandle, mfiter: MFIterHandle
) raises -> Box3DResult:
    var small_end = List[c_int](length=3, fill=0)
    var big_end = List[c_int](length=3, fill=0)
    var nodal = List[c_int](length=3, fill=0)
    var status = Int(
        lib.call["amrex_mojo_mfiter_tile_box_metadata", c_int](
            mfiter,
            small_end.unsafe_ptr(),
            big_end.unsafe_ptr(),
            nodal.unsafe_ptr(),
        )
    )
    return Box3DResult(
        status=status,
        value=box_from_parts(small_end, big_end, nodal),
    )


def mfiter_valid_box(
    ref lib: OwnedDLHandle, mfiter: MFIterHandle
) raises -> Box3DResult:
    var small_end = List[c_int](length=3, fill=0)
    var big_end = List[c_int](length=3, fill=0)
    var nodal = List[c_int](length=3, fill=0)
    var status = Int(
        lib.call["amrex_mojo_mfiter_valid_box_metadata", c_int](
            mfiter,
            small_end.unsafe_ptr(),
            big_end.unsafe_ptr(),
            nodal.unsafe_ptr(),
        )
    )
    return Box3DResult(
        status=status,
        value=box_from_parts(small_end, big_end, nodal),
    )


def mfiter_fab_box(
    ref lib: OwnedDLHandle, mfiter: MFIterHandle
) raises -> Box3DResult:
    var small_end = List[c_int](length=3, fill=0)
    var big_end = List[c_int](length=3, fill=0)
    var nodal = List[c_int](length=3, fill=0)
    var status = Int(
        lib.call["amrex_mojo_mfiter_fab_box_metadata", c_int](
            mfiter,
            small_end.unsafe_ptr(),
            big_end.unsafe_ptr(),
            nodal.unsafe_ptr(),
        )
    )
    return Box3DResult(
        status=status,
        value=box_from_parts(small_end, big_end, nodal),
    )


def mfiter_growntile_box(
    ref lib: OwnedDLHandle, mfiter: MFIterHandle, ngrow: IntVect3D
) raises -> Box3DResult:
    var small_end = List[c_int](length=3, fill=0)
    var big_end = List[c_int](length=3, fill=0)
    var nodal = List[c_int](length=3, fill=0)
    var status = Int(
        lib.call["amrex_mojo_mfiter_growntile_box_metadata", c_int](
            mfiter,
            ngrow,
            small_end.unsafe_ptr(),
            big_end.unsafe_ptr(),
            nodal.unsafe_ptr(),
        )
    )
    return Box3DResult(
        status=status,
        value=box_from_parts(small_end, big_end, nodal),
    )


def box_from_bounds(lo_raw: List[c_int], hi_raw: List[c_int]) raises -> Box3D:
    return box3d(
        small_end=intvect3d(Int(lo_raw[0]), Int(lo_raw[1]), Int(lo_raw[2])),
        big_end=intvect3d(Int(hi_raw[0]), Int(hi_raw[1]), Int(hi_raw[2])),
    )


def box_from_parts(
    lo_raw: List[c_int], hi_raw: List[c_int], nodal_raw: List[c_int]
) raises -> Box3D:
    return box3d(
        small_end=intvect3d(Int(lo_raw[0]), Int(lo_raw[1]), Int(lo_raw[2])),
        big_end=intvect3d(Int(hi_raw[0]), Int(hi_raw[1]), Int(hi_raw[2])),
        nodal=intvect3d(
            Int(nodal_raw[0]), Int(nodal_raw[1]), Int(nodal_raw[2])
        ),
    )


def tile_view[owner_origin: Origin[mut=True]](
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> TileF64View[owner_origin]:
    var tile_lo = List[c_int](length=3, fill=0)
    var tile_hi = List[c_int](length=3, fill=0)
    var valid_lo = List[c_int](length=3, fill=0)
    var valid_hi = List[c_int](length=3, fill=0)
    var data_lo = List[c_int](length=3, fill=0)
    var data_hi = List[c_int](length=3, fill=0)
    var stride = List[Int64](length=4, fill=0)
    var ncomp_raw = List[c_int](length=1, fill=0)

    _ = lib.call["amrex_mojo_multifab_tile_metadata", c_int](
        multifab,
        c_int(tile_index),
        tile_lo.unsafe_ptr(),
        tile_hi.unsafe_ptr(),
        valid_lo.unsafe_ptr(),
        valid_hi.unsafe_ptr(),
        data_lo.unsafe_ptr(),
        data_hi.unsafe_ptr(),
        stride.unsafe_ptr(),
        ncomp_raw.unsafe_ptr(),
    )

    var array_view = Array4F64View[owner_origin](
        data=lib.call[
            "amrex_mojo_multifab_data_ptr",
            UnsafePointer[c_double, owner_origin],
        ](
            multifab, c_int(tile_index)
        ),
        lo_x=data_lo[0],
        lo_y=data_lo[1],
        lo_z=data_lo[2],
        hi_x=data_hi[0],
        hi_y=data_hi[1],
        hi_z=data_hi[2],
        stride_i=stride[0],
        stride_j=stride[1],
        stride_k=stride[2],
        stride_n=stride[3],
        ncomp=ncomp_raw[0],
    )

    return TileF64View[owner_origin](
        tile_box=box_from_bounds(tile_lo, tile_hi),
        valid_box=box_from_bounds(valid_lo, valid_hi),
        array_view=array_view.copy(),
    )


def array4_view_from_mfiter[owner_origin: Origin[mut=True]](
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> Array4F64View[owner_origin]:
    var data_lo = List[c_int](length=3, fill=0)
    var data_hi = List[c_int](length=3, fill=0)
    var stride = List[Int64](length=4, fill=0)
    var ncomp_raw = List[c_int](length=1, fill=0)

    _ = lib.call["amrex_mojo_multifab_array4_metadata_for_mfiter", c_int](
        multifab,
        mfiter,
        data_lo.unsafe_ptr(),
        data_hi.unsafe_ptr(),
        stride.unsafe_ptr(),
        ncomp_raw.unsafe_ptr(),
    )

    return Array4F64View[owner_origin](
        data=lib.call[
            "amrex_mojo_multifab_data_ptr_for_mfiter",
            UnsafePointer[c_double, owner_origin],
        ](multifab, mfiter),
        lo_x=data_lo[0],
        lo_y=data_lo[1],
        lo_z=data_lo[2],
        hi_x=data_hi[0],
        hi_y=data_hi[1],
        hi_z=data_hi[2],
        stride_i=stride[0],
        stride_j=stride[1],
        stride_k=stride[2],
        stride_n=stride[3],
        ncomp=ncomp_raw[0],
    )


def multifab_sum(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return lib.call["amrex_mojo_multifab_sum", c_double](multifab, c_int(comp))


def boxarray_box(
    ref lib: OwnedDLHandle, boxarray: BoxArrayHandle, index: Int
) raises -> Box3DResult:
    var small_end = List[c_int](length=3, fill=0)
    var big_end = List[c_int](length=3, fill=0)
    var nodal = List[c_int](length=3, fill=0)
    var status = Int(
        lib.call["amrex_mojo_boxarray_box_metadata", c_int](
            boxarray,
            c_int(index),
            small_end.unsafe_ptr(),
            big_end.unsafe_ptr(),
            nodal.unsafe_ptr(),
        )
    )
    return Box3DResult(
        status=status,
        value=box_from_parts(small_end, big_end, nodal),
    )


def geometry_domain(
    ref lib: OwnedDLHandle, geometry: GeometryHandle
) raises -> Box3DResult:
    var small_end = List[c_int](length=3, fill=0)
    var big_end = List[c_int](length=3, fill=0)
    var nodal = List[c_int](length=3, fill=0)
    var status = Int(
        lib.call["amrex_mojo_geometry_domain_metadata", c_int](
            geometry,
            small_end.unsafe_ptr(),
            big_end.unsafe_ptr(),
            nodal.unsafe_ptr(),
        )
    )
    return Box3DResult(
        status=status,
        value=box_from_parts(small_end, big_end, nodal),
    )


def geometry_prob_domain(
    ref lib: OwnedDLHandle, geometry: GeometryHandle
) raises -> RealBox3DResult:
    var lo = List[Float64](length=3, fill=0.0)
    var hi = List[Float64](length=3, fill=0.0)
    var status = Int(
        lib.call["amrex_mojo_geometry_prob_domain_metadata", c_int](
            geometry,
            lo.unsafe_ptr(),
            hi.unsafe_ptr(),
        )
    )
    return RealBox3DResult(
        status=status,
        value=RealBox3D(
            lo_x=lo[0],
            lo_y=lo[1],
            lo_z=lo[2],
            hi_x=hi[0],
            hi_y=hi[1],
            hi_z=hi[2],
        ),
    )


def geometry_cell_size(
    ref lib: OwnedDLHandle, geometry: GeometryHandle
) raises -> RealVect3DResult:
    var cell_size = List[Float64](length=3, fill=0.0)
    var status = Int(
        lib.call["amrex_mojo_geometry_cell_size_data", c_int](
            geometry,
            cell_size.unsafe_ptr(),
        )
    )
    return RealVect3DResult(
        status=status,
        value=RealVect3D(
            x=cell_size[0],
            y=cell_size[1],
            z=cell_size[2],
        ),
    )


def geometry_periodicity(
    ref lib: OwnedDLHandle, geometry: GeometryHandle
) raises -> IntVect3DResult:
    var periodicity = List[c_int](length=3, fill=0)
    var status = Int(
        lib.call["amrex_mojo_geometry_periodicity_data", c_int](
            geometry,
            periodicity.unsafe_ptr(),
        )
    )
    return IntVect3DResult(
        status=status,
        value=intvect3d(
            Int(periodicity[0]),
            Int(periodicity[1]),
            Int(periodicity[2]),
        ),
    )


def multifab_min(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return lib.call["amrex_mojo_multifab_min", c_double](multifab, c_int(comp))


def multifab_max(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return lib.call["amrex_mojo_multifab_max", c_double](multifab, c_int(comp))


def multifab_norm0(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return lib.call["amrex_mojo_multifab_norm0", c_double](
        multifab, c_int(comp)
    )


def multifab_norm1(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return lib.call["amrex_mojo_multifab_norm1", c_double](
        multifab, c_int(comp)
    )


def multifab_norm2(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return lib.call["amrex_mojo_multifab_norm2", c_double](
        multifab, c_int(comp)
    )


def multifab_plus(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    return Int(
        lib.call["amrex_mojo_multifab_plus", c_int](
            multifab,
            c_double(value),
            c_int(start_comp),
            c_int(ncomp),
            ngrow,
        )
    )


def multifab_mult(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    return Int(
        lib.call["amrex_mojo_multifab_mult", c_int](
            multifab,
            c_double(value),
            c_int(start_comp),
            c_int(ncomp),
            ngrow,
        )
    )


def multifab_copy(
    ref lib: OwnedDLHandle,
    dst_multifab: MultiFabHandle,
    src_multifab: MultiFabHandle,
    src_comp: Int,
    dst_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    return Int(
        lib.call["amrex_mojo_multifab_copy", c_int](
            dst_multifab,
            src_multifab,
            c_int(src_comp),
            c_int(dst_comp),
            c_int(ncomp),
            ngrow,
        )
    )


def multifab_write_single_level_plotfile(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    geometry: GeometryHandle,
    plotfile: String,
    time: Float64,
    level_step: Int,
) raises -> Int:
    var plotfile_owned = plotfile
    return Int(
        lib.call["amrex_mojo_write_single_level_plotfile", c_int](
            multifab,
            geometry,
            plotfile_owned.as_c_string_slice().unsafe_ptr(),
            c_double(time),
            c_int(level_step),
        )
    )


def multifab_write_single_level_plotfile(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    geometry: GeometryHandle,
    plotfile: StringLiteral,
    time: Float64,
    level_step: Int,
) raises -> Int:
    return Int(
        lib.call["amrex_mojo_write_single_level_plotfile", c_int](
            multifab,
            geometry,
            plotfile.as_c_string_slice().unsafe_ptr(),
            c_double(time),
            c_int(level_step),
        )
    )


def parmparse_create(
    ref lib: OwnedDLHandle, runtime: RuntimeHandle, prefix: String
) raises -> ParmParseHandle:
    var prefix_owned = prefix
    return lib.call["amrex_mojo_parmparse_create", ParmParseHandle](
        runtime, prefix_owned.as_c_string_slice().unsafe_ptr()
    )


def parmparse_create(
    ref lib: OwnedDLHandle, runtime: RuntimeHandle, prefix: StringLiteral
) raises -> ParmParseHandle:
    return lib.call["amrex_mojo_parmparse_create", ParmParseHandle](
        runtime, prefix.as_c_string_slice().unsafe_ptr()
    )


def parmparse_destroy(ref lib: OwnedDLHandle, parmparse: ParmParseHandle) raises:
    lib.call["amrex_mojo_parmparse_destroy"](parmparse)


def parmparse_add_int(
    ref lib: OwnedDLHandle,
    parmparse: ParmParseHandle,
    name: String,
    value: Int,
) raises -> Int:
    var name_owned = name
    return Int(
        lib.call["amrex_mojo_parmparse_add_int", c_int](
            parmparse,
            name_owned.as_c_string_slice().unsafe_ptr(),
            c_int(value),
        )
    )


def parmparse_add_int(
    ref lib: OwnedDLHandle,
    parmparse: ParmParseHandle,
    name: StringLiteral,
    value: Int,
) raises -> Int:
    return Int(
        lib.call["amrex_mojo_parmparse_add_int", c_int](
            parmparse,
            name.as_c_string_slice().unsafe_ptr(),
            c_int(value),
        )
    )


def parmparse_query_int(
    ref lib: OwnedDLHandle, parmparse: ParmParseHandle, name: String
) raises -> ParmParseIntQueryResult:
    var name_owned = name
    var out_value = List[c_int](length=1, fill=0)
    var out_found = List[c_int](length=1, fill=0)
    var status = Int(
        lib.call["amrex_mojo_parmparse_query_int", c_int](
            parmparse,
            name_owned.as_c_string_slice().unsafe_ptr(),
            out_value.unsafe_ptr(),
            out_found.unsafe_ptr(),
        )
    )
    return ParmParseIntQueryResult(
        status=status,
        found=out_found[0] != 0,
        value=Int(out_value[0]),
    )


def parmparse_query_int(
    ref lib: OwnedDLHandle, parmparse: ParmParseHandle, name: StringLiteral
) raises -> ParmParseIntQueryResult:
    var out_value = List[c_int](length=1, fill=0)
    var out_found = List[c_int](length=1, fill=0)
    var status = Int(
        lib.call["amrex_mojo_parmparse_query_int", c_int](
            parmparse,
            name.as_c_string_slice().unsafe_ptr(),
            out_value.unsafe_ptr(),
            out_found.unsafe_ptr(),
        )
    )
    return ParmParseIntQueryResult(
        status=status,
        found=out_found[0] != 0,
        value=Int(out_value[0]),
    )
