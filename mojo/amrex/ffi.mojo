from std.collections import List
from std.ffi import OwnedDLHandle, c_char, c_double, c_int


comptime RuntimeHandle = UnsafePointer[NoneType, MutAnyOrigin]
comptime BoxArrayHandle = UnsafePointer[NoneType, MutAnyOrigin]
comptime DistributionMappingHandle = UnsafePointer[NoneType, MutAnyOrigin]
comptime GeometryHandle = UnsafePointer[NoneType, MutAnyOrigin]
comptime MultiFabHandle = UnsafePointer[NoneType, MutAnyOrigin]
comptime ParmParseHandle = UnsafePointer[NoneType, MutAnyOrigin]
comptime RealPtr = UnsafePointer[c_double, MutAnyOrigin]


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
struct Array4F64View(Copyable):
    var data: RealPtr
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

    fn offset(self, i: Int, j: Int, k: Int, comp: Int = 0) -> Int:
        return (
            (i - Int(self.lo_x)) * Int(self.stride_i)
            + (j - Int(self.lo_y)) * Int(self.stride_j)
            + (k - Int(self.lo_z)) * Int(self.stride_k)
            + comp * Int(self.stride_n)
        )

    fn load(self, i: Int, j: Int, k: Int, comp: Int = 0) -> Float64:
        return self.data[self.offset(i, j, k, comp)]

    fn store(self, i: Int, j: Int, k: Int, value: Float64, comp: Int = 0):
        self.data[self.offset(i, j, k, comp)] = value

    fn fill(self, box: Box3D, value: Float64, comp: Int = 0):
        for k in range(Int(box.small_end.z), Int(box.big_end.z) + 1):
            for j in range(Int(box.small_end.y), Int(box.big_end.y) + 1):
                for i in range(Int(box.small_end.x), Int(box.big_end.x) + 1):
                    self.store(i, j, k, value, comp)


@fieldwise_init
struct TileF64View(Copyable):
    var tile_box: Box3D
    var valid_box: Box3D
    var array_view: Array4F64View

    fn array(self) -> Array4F64View:
        return self.array_view.copy()

    fn fill(self, value: Float64, comp: Int = 0):
        self.array_view.fill(self.tile_box, value, comp)


fn intvect3d(x: Int, y: Int, z: Int) -> IntVect3D:
    return IntVect3D(x=c_int(x), y=c_int(y), z=c_int(z))


fn zero_intvect3d() -> IntVect3D:
    return intvect3d(0, 0, 0)


fn box3d(
    small_end: IntVect3D,
    big_end: IntVect3D,
    nodal: IntVect3D = zero_intvect3d(),
) -> Box3D:
    return Box3D(
        small_end=small_end.copy(),
        big_end=big_end.copy(),
        nodal=nodal.copy(),
    )


fn last_error_message(ref lib: OwnedDLHandle) -> String:
    var message = lib.call[
        "amrex_mojo_last_error_message",
        UnsafePointer[c_char, MutAnyOrigin],
    ]()
    if not message:
        return String("AMReX call failed.")
    return String(unsafe_from_utf8_ptr=message)


fn abi_version(ref lib: OwnedDLHandle) -> Int:
    return Int(lib.call["amrex_mojo_abi_version", c_int]())


fn runtime_create(ref lib: OwnedDLHandle) -> RuntimeHandle:
    return lib.call["amrex_mojo_runtime_create_default", RuntimeHandle]()


fn runtime_destroy(ref lib: OwnedDLHandle, runtime: RuntimeHandle):
    lib.call["amrex_mojo_runtime_destroy"](runtime)


fn runtime_initialized(ref lib: OwnedDLHandle, runtime: RuntimeHandle) -> Bool:
    return lib.call["amrex_mojo_runtime_initialized", c_int](runtime) != 0


fn parallel_nprocs(ref lib: OwnedDLHandle) -> Int:
    return Int(lib.call["amrex_mojo_parallel_nprocs", c_int]())


fn parallel_myproc(ref lib: OwnedDLHandle) -> Int:
    return Int(lib.call["amrex_mojo_parallel_myproc", c_int]())


fn parallel_ioprocessor(ref lib: OwnedDLHandle) -> Bool:
    return lib.call["amrex_mojo_parallel_ioprocessor", c_int]() != 0


fn parallel_ioprocessor_number(ref lib: OwnedDLHandle) -> Int:
    return Int(lib.call["amrex_mojo_parallel_ioprocessor_number", c_int]())


fn boxarray_create_from_box(
    ref lib: OwnedDLHandle, runtime: RuntimeHandle, domain: Box3D
) -> BoxArrayHandle:
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


fn boxarray_destroy(ref lib: OwnedDLHandle, boxarray: BoxArrayHandle):
    lib.call["amrex_mojo_boxarray_destroy"](boxarray)


fn boxarray_max_size(
    ref lib: OwnedDLHandle, boxarray: BoxArrayHandle, max_size: IntVect3D
) -> Int:
    return Int(
        lib.call["amrex_mojo_boxarray_max_size_xyz", c_int](
            boxarray, max_size.x, max_size.y, max_size.z
        )
    )


fn boxarray_size(ref lib: OwnedDLHandle, boxarray: BoxArrayHandle) -> Int:
    return Int(lib.call["amrex_mojo_boxarray_size", c_int](boxarray))


fn distmap_create_from_boxarray(
    ref lib: OwnedDLHandle,
    runtime: RuntimeHandle,
    boxarray: BoxArrayHandle,
) -> DistributionMappingHandle:
    return lib.call[
        "amrex_mojo_distmap_create_from_boxarray", DistributionMappingHandle
    ](runtime, boxarray)


fn distmap_destroy(ref lib: OwnedDLHandle, distmap: DistributionMappingHandle):
    lib.call["amrex_mojo_distmap_destroy"](distmap)


fn geometry_create(
    ref lib: OwnedDLHandle, runtime: RuntimeHandle, domain: Box3D
) -> GeometryHandle:
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


fn geometry_destroy(ref lib: OwnedDLHandle, geometry: GeometryHandle):
    lib.call["amrex_mojo_geometry_destroy"](geometry)


fn multifab_create(
    ref lib: OwnedDLHandle,
    runtime: RuntimeHandle,
    boxarray: BoxArrayHandle,
    distmap: DistributionMappingHandle,
    ncomp: Int,
    ngrow: IntVect3D,
) -> MultiFabHandle:
    return lib.call["amrex_mojo_multifab_create_xyz", MultiFabHandle](
        runtime,
        boxarray,
        distmap,
        c_int(ncomp),
        ngrow.x,
        ngrow.y,
        ngrow.z,
    )


fn multifab_destroy(ref lib: OwnedDLHandle, multifab: MultiFabHandle):
    lib.call["amrex_mojo_multifab_destroy"](multifab)


fn multifab_ncomp(ref lib: OwnedDLHandle, multifab: MultiFabHandle) -> Int:
    return Int(lib.call["amrex_mojo_multifab_ncomp", c_int](multifab))


fn multifab_set_val(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
) -> Int:
    return Int(
        lib.call["amrex_mojo_multifab_set_val", c_int](
            multifab, c_double(value), c_int(start_comp), c_int(ncomp)
        )
    )


fn multifab_tile_count(ref lib: OwnedDLHandle, multifab: MultiFabHandle) -> Int:
    return Int(lib.call["amrex_mojo_multifab_tile_count", c_int](multifab))


fn box_from_bounds(lo_raw: List[c_int], hi_raw: List[c_int]) -> Box3D:
    return box3d(
        small_end=intvect3d(Int(lo_raw[0]), Int(lo_raw[1]), Int(lo_raw[2])),
        big_end=intvect3d(Int(hi_raw[0]), Int(hi_raw[1]), Int(hi_raw[2])),
    )


fn tile_view(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) -> TileF64View:
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

    var array_view = Array4F64View(
        data=lib.call["amrex_mojo_multifab_data_ptr", RealPtr](
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

    return TileF64View(
        tile_box=box_from_bounds(tile_lo, tile_hi),
        valid_box=box_from_bounds(valid_lo, valid_hi),
        array_view=array_view.copy(),
    )


fn multifab_sum(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) -> Float64:
    return lib.call["amrex_mojo_multifab_sum", c_double](multifab, c_int(comp))


fn multifab_min(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) -> Float64:
    return lib.call["amrex_mojo_multifab_min", c_double](multifab, c_int(comp))


fn multifab_max(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) -> Float64:
    return lib.call["amrex_mojo_multifab_max", c_double](multifab, c_int(comp))


fn multifab_norm0(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) -> Float64:
    return lib.call["amrex_mojo_multifab_norm0", c_double](
        multifab, c_int(comp)
    )


fn multifab_norm1(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) -> Float64:
    return lib.call["amrex_mojo_multifab_norm1", c_double](
        multifab, c_int(comp)
    )


fn multifab_norm2(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) -> Float64:
    return lib.call["amrex_mojo_multifab_norm2", c_double](
        multifab, c_int(comp)
    )


fn multifab_plus(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) -> Int:
    return Int(
        lib.call["amrex_mojo_multifab_plus", c_int](
            multifab,
            c_double(value),
            c_int(start_comp),
            c_int(ncomp),
            ngrow,
        )
    )


fn multifab_mult(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) -> Int:
    return Int(
        lib.call["amrex_mojo_multifab_mult", c_int](
            multifab,
            c_double(value),
            c_int(start_comp),
            c_int(ncomp),
            ngrow,
        )
    )


fn multifab_copy(
    ref lib: OwnedDLHandle,
    dst_multifab: MultiFabHandle,
    src_multifab: MultiFabHandle,
    src_comp: Int,
    dst_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) -> Int:
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
