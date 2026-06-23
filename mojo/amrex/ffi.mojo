# ABOUTME: Low-level C FFI wrappers and value types for the AMReX C API.
# ABOUTME: Defines handles, device-passable structs, and ABI helper functions.

from std.collections import List
from std.builtin.device_passable import DevicePassable, DeviceTypeEncoder
from std.ffi import OwnedDLHandle, c_char, c_double, c_int
from amrex.floating_dtype import (
    AmrexFloatingDtype,
    MULTIFAB_DATATYPE_FLOAT32,
    MULTIFAB_DATATYPE_FLOAT64,
)


comptime RuntimeHandle = UnsafePointer[NoneType, MutUntrackedOrigin]
comptime BoxArrayHandle = UnsafePointer[NoneType, MutUntrackedOrigin]
comptime DistributionMappingHandle = UnsafePointer[NoneType, MutUntrackedOrigin]
comptime GeometryHandle = UnsafePointer[NoneType, MutUntrackedOrigin]
comptime MultiFabHandle = UnsafePointer[NoneType, MutUntrackedOrigin]
comptime MFIterHandle = UnsafePointer[NoneType, MutUntrackedOrigin]
comptime ParmParseHandle = UnsafePointer[NoneType, MutUntrackedOrigin]
comptime GpuStreamHandle = UnsafePointer[NoneType, MutUntrackedOrigin]

comptime OptionalRuntimeHandle = Optional[RuntimeHandle]
comptime OptionalBoxArrayHandle = Optional[BoxArrayHandle]
comptime OptionalDistributionMappingHandle = Optional[DistributionMappingHandle]
comptime OptionalGeometryHandle = Optional[GeometryHandle]
comptime OptionalMultiFabHandle = Optional[MultiFabHandle]
comptime OptionalMFIterHandle = Optional[MFIterHandle]
comptime OptionalParmParseHandle = Optional[ParmParseHandle]
comptime OptionalGpuStreamHandle = Optional[GpuStreamHandle]
comptime CStringHandle = UnsafePointer[c_char, ImmutUntrackedOrigin]
comptime OptionalCStringHandle = Optional[CStringHandle]
comptime CStringArrayHandle = UnsafePointer[CStringHandle, MutUntrackedOrigin]
comptime OptionalCStringArrayHandle = Optional[CStringArrayHandle]

comptime GPU_BACKEND_NONE = 0
comptime GPU_BACKEND_CUDA = 1
comptime GPU_BACKEND_HIP = 2


def init_device_passable_value[
    T: TrivialRegisterPassable,
    mut_origin: MutOrigin,
](value: T, target: UnsafePointer[NoneType, mut_origin]):
    target.bitcast[T]().init_pointee_copy(value)


@fieldwise_init
struct IntVect3D(DevicePassable, TrivialRegisterPassable, Writable):
    comptime device_type = Self

    var x: c_int
    var y: c_int
    var z: c_int

    def _to_device_type(
        self,
        mut encoder: Some[DeviceTypeEncoder],
        target: UnsafePointer[mut=True, NoneType, _],
    ):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("IntVect3D")


@fieldwise_init
struct Box3D(DevicePassable, TrivialRegisterPassable, Writable):
    comptime device_type = Self

    var small_end: IntVect3D
    var big_end: IntVect3D
    var nodal: IntVect3D

    def _to_device_type(
        self,
        mut encoder: Some[DeviceTypeEncoder],
        target: UnsafePointer[mut=True, NoneType, _],
    ):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("Box3D")


@fieldwise_init
struct RealBox3D(Copyable, RegisterPassable, Writable):
    var lo_x: Float64
    var lo_y: Float64
    var lo_z: Float64
    var hi_x: Float64
    var hi_y: Float64
    var hi_z: Float64


@fieldwise_init
struct RealVect3D(DevicePassable, TrivialRegisterPassable, Writable):
    comptime device_type = Self

    var x: Float64
    var y: Float64
    var z: Float64

    def _to_device_type(
        self,
        mut encoder: Some[DeviceTypeEncoder],
        target: UnsafePointer[mut=True, NoneType, _],
    ):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("RealVect3D")


@fieldwise_init
struct ParmParseIntQueryResult(Copyable):
    var status: Int
    var found: Bool
    var value: Int


@fieldwise_init
struct ParmParseRealQueryResult(Copyable):
    var status: Int
    var found: Bool
    var value: Float64


@fieldwise_init
struct MultiFabMemoryInfo(Copyable):
    var requested_kind: Int
    var host_accessible: Bool
    var device_accessible: Bool
    var is_managed: Bool
    var is_device: Bool
    var is_pinned: Bool


@fieldwise_init
struct Array4LayoutMetadata(Copyable, DevicePassable, TrivialRegisterPassable, Writable):
    comptime device_type = Self

    var lo_x: Int
    var lo_y: Int
    var lo_z: Int
    var hi_x: Int
    var hi_y: Int
    var hi_z: Int
    var stride_i: Int
    var stride_j: Int
    var stride_k: Int
    var stride_n: Int
    var ncomp: Int

    def _to_device_type(
        self,
        mut encoder: Some[DeviceTypeEncoder],
        target: UnsafePointer[mut=True, NoneType, _],
    ):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("Array4LayoutMetadata")

    def storage_size(self) -> Int:
        var nx = self.hi_x - self.lo_x + 1
        var ny = self.hi_y - self.lo_y + 1
        var nz = self.hi_z - self.lo_z + 1
        return (
            (nx - 1) * self.stride_i
            + (ny - 1) * self.stride_j
            + (nz - 1) * self.stride_k
            + (self.ncomp - 1) * self.stride_n
            + 1
        )

    def offset(self, i: Int, j: Int, k: Int, comp: Int = 0) -> Int:
        return (
            (i - self.lo_x) * self.stride_i
            + (j - self.lo_y) * self.stride_j
            + (k - self.lo_z) * self.stride_k
            + comp * self.stride_n
        )

    def get[
        dtype: DType, origin: Origin[mut=True]
    ](self, data: UnsafePointer[Scalar[dtype], origin], i: Int, j: Int, k: Int, comp: Int,) -> Scalar[dtype]:
        return data[self.offset(i, j, k, comp)]

    def set[
        dtype: DType, origin: Origin[mut=True]
    ](self, data: UnsafePointer[Scalar[dtype], origin], i: Int, j: Int, k: Int, comp: Int, value: Scalar[dtype],):
        data[self.offset(i, j, k, comp)] = value


@fieldwise_init
struct Array4View[T: AmrexFloatingDtype, origin: Origin[mut=True]](DevicePassable, TrivialRegisterPassable):
    comptime dtype = Self.T.dtype
    comptime device_type = Array4View[Self.T, MutUnsafeAnyOrigin]
    comptime value_type = Scalar[Self.dtype]

    var data: UnsafePointer[Self.value_type, Self.origin]
    var layout: Array4LayoutMetadata

    def device_view(self) -> Self.device_type:
        return Self.device_type(
            data=self.data.as_unsafe_any_origin(),
            layout=self.layout.copy(),
        )

    def _to_device_type(
        self,
        mut encoder: Some[DeviceTypeEncoder],
        target: UnsafePointer[mut=True, NoneType, _],
    ):
        init_device_passable_value(self.device_view(), target)

    @staticmethod
    def get_type_name() -> String:
        return String(Self.T.array4_view_type_name)

    def layout_metadata(self) -> Array4LayoutMetadata:
        return self.layout.copy()

    def storage_size(self) -> Int:
        return self.layout.storage_size()

    def offset(self, i: Int, j: Int, k: Int, comp: Int = 0) -> Int:
        return self.layout.offset(i, j, k, comp)

    def __getitem__(self, i: Int, j: Int, k: Int) -> Self.value_type:
        return self[i, j, k, 0]

    def __getitem__(self, i: Int, j: Int, k: Int, comp: Int) -> Self.value_type:
        return self.layout.get[Self.dtype, Self.origin](self.data, i, j, k, comp)

    def __setitem__(self, i: Int, j: Int, k: Int, value: Self.value_type):
        self[i, j, k, 0] = value

    def __setitem__(self, i: Int, j: Int, k: Int, comp: Int, value: Self.value_type):
        self.layout.set[Self.dtype, Self.origin](self.data, i, j, k, comp, value)

    def fill(self, box: Box3D, value: Self.value_type, comp: Int = 0):
        for k in range(Int(box.small_end.z), Int(box.big_end.z) + 1):
            for j in range(Int(box.small_end.y), Int(box.big_end.y) + 1):
                for i in range(Int(box.small_end.x), Int(box.big_end.x) + 1):
                    self[i, j, k, comp] = value


@fieldwise_init
struct TileView[T: AmrexFloatingDtype, origin: Origin[mut=True]](DevicePassable, TrivialRegisterPassable):
    comptime dtype = Self.T.dtype
    comptime device_type = TileView[Self.T, MutUnsafeAnyOrigin]
    comptime value_type = Scalar[Self.dtype]

    var tile_box: Box3D
    var valid_box: Box3D
    var array_view: Array4View[Self.T, Self.origin]

    def device_view(self) -> Self.device_type:
        return Self.device_type(
            tile_box=self.tile_box.copy(),
            valid_box=self.valid_box.copy(),
            array_view=self.array_view.device_view(),
        )

    def _to_device_type(
        self,
        mut encoder: Some[DeviceTypeEncoder],
        target: UnsafePointer[mut=True, NoneType, _],
    ):
        init_device_passable_value(self.device_view(), target)

    @staticmethod
    def get_type_name() -> String:
        return String(Self.T.tile_view_type_name)

    def array(self) -> Array4View[Self.T, Self.origin]:
        return self.array_view.copy()

    def fill(self, value: Self.value_type, comp: Int = 0):
        self.array_view.fill(self.tile_box, value, comp)


def intvect3d(x: Int, y: Int, z: Int) raises -> IntVect3D:
    return IntVect3D(x=c_int(x), y=c_int(y), z=c_int(z))


def zero_intvect3d() raises -> IntVect3D:
    return intvect3d(0, 0, 0)


def realbox3d(
    lo_x: Float64,
    lo_y: Float64,
    lo_z: Float64,
    hi_x: Float64,
    hi_y: Float64,
    hi_z: Float64,
) -> RealBox3D:
    return RealBox3D(
        lo_x=lo_x,
        lo_y=lo_y,
        lo_z=lo_z,
        hi_x=hi_x,
        hi_y=hi_y,
        hi_z=hi_z,
    )


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


comptime BOX_DIM = 3


def box_cell_count(box: Box3D) -> Int:
    return (
        (Int(box.big_end.x) - Int(box.small_end.x) + 1)
        * (Int(box.big_end.y) - Int(box.small_end.y) + 1)
        * (Int(box.big_end.z) - Int(box.small_end.z) + 1)
    )


def for_each_box_cell[
    body_type: (def(Int, Int, Int) -> None) & DevicePassable & ImplicitlyCopyable
](box: Box3D, body: body_type):
    for k in range(Int(box.small_end.z), Int(box.big_end.z) + 1):
        for j in range(Int(box.small_end.y), Int(box.big_end.y) + 1):
            for i in range(Int(box.small_end.x), Int(box.big_end.x) + 1):
                body(i, j, k)


def last_error_message(ref lib: OwnedDLHandle) raises -> String:
    var message = lib.call[
        "amrex_mojo_last_error_message",
        Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]],
    ]()
    if not message:
        return String("AMReX call failed.")
    return String(unsafe_from_utf8_ptr=message.value())


def raise_on_error(ref lib: OwnedDLHandle, status: Int) raises:
    if status != 0:
        raise Error(last_error_message(lib))


def abi_version(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_abi_version", c_int]())


def runtime_create(ref lib: OwnedDLHandle) raises -> OptionalRuntimeHandle:
    return lib.call["amrex_mojo_runtime_create_default", OptionalRuntimeHandle]()


def runtime_create(ref lib: OwnedDLHandle, device_id: Int) raises -> OptionalRuntimeHandle:
    return lib.call[
        "amrex_mojo_runtime_create_default_on_device",
        OptionalRuntimeHandle,
    ](c_int(device_id))


def runtime_create(
    ref lib: OwnedDLHandle,
    argv: List[String],
    use_parmparse: Bool = False,
) raises -> OptionalRuntimeHandle:
    var argc = len(argv)
    if argc == 0:
        var argv_null: OptionalCStringArrayHandle = None
        return lib.call["amrex_mojo_runtime_create", OptionalRuntimeHandle](
            c_int(0),
            argv_null,
            c_int(1 if use_parmparse else 0),
        )

    var argv_storage = List[String](length=argc, fill=String(""))
    for i in range(argc):
        argv_storage[i] = argv[i].copy()

    var first_ptr = argv_storage[0].as_c_string_slice().unsafe_ptr()
    var argv_ptrs = List[type_of(first_ptr)](length=argc, fill=first_ptr)
    for i in range(1, argc):
        argv_ptrs[i] = argv_storage[i].as_c_string_slice().unsafe_ptr()

    return lib.call["amrex_mojo_runtime_create", OptionalRuntimeHandle](
        c_int(argc),
        argv_ptrs.unsafe_ptr(),
        c_int(1 if use_parmparse else 0),
    )


def runtime_create(
    ref lib: OwnedDLHandle,
    argv: List[String],
    use_parmparse: Bool,
    device_id: Int,
) raises -> OptionalRuntimeHandle:
    var argc = len(argv)
    if argc == 0:
        var argv_null: OptionalCStringArrayHandle = None
        return lib.call[
            "amrex_mojo_runtime_create_on_device",
            OptionalRuntimeHandle,
        ](
            c_int(0),
            argv_null,
            c_int(1 if use_parmparse else 0),
            c_int(device_id),
        )

    var argv_storage = List[String](length=argc, fill=String(""))
    for i in range(argc):
        argv_storage[i] = argv[i].copy()

    var first_ptr = argv_storage[0].as_c_string_slice().unsafe_ptr()
    var argv_ptrs = List[type_of(first_ptr)](length=argc, fill=first_ptr)
    for i in range(1, argc):
        argv_ptrs[i] = argv_storage[i].as_c_string_slice().unsafe_ptr()

    return lib.call[
        "amrex_mojo_runtime_create_on_device",
        OptionalRuntimeHandle,
    ](
        c_int(argc),
        argv_ptrs.unsafe_ptr(),
        c_int(1 if use_parmparse else 0),
        c_int(device_id),
    )


def runtime_destroy(ref lib: OwnedDLHandle, runtime: RuntimeHandle) raises:
    lib.call["amrex_mojo_runtime_destroy"](runtime)


def runtime_initialized(ref lib: OwnedDLHandle, runtime: RuntimeHandle) raises -> Bool:
    return lib.call["amrex_mojo_runtime_initialized", c_int](runtime) != 0


def gpu_backend(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_gpu_backend", c_int]())


def gpu_device_id(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_gpu_device_id", c_int]())


def gpu_num_streams(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_gpu_num_streams", c_int]())


def gpu_set_stream_index(ref lib: OwnedDLHandle, stream_index: Int) raises -> Int:
    return Int(lib.call["amrex_mojo_gpu_set_stream_index", c_int](c_int(stream_index)))


def gpu_reset_stream(ref lib: OwnedDLHandle) raises:
    lib.call["amrex_mojo_gpu_reset_stream"]()


def gpu_stream(
    ref lib: OwnedDLHandle,
) raises -> OptionalGpuStreamHandle:
    return lib.call[
        "amrex_mojo_gpu_stream",
        OptionalGpuStreamHandle,
    ]()


def gpu_stream_synchronize_active(ref lib: OwnedDLHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_gpu_stream_synchronize_active", c_int]())


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
) raises -> OptionalBoxArrayHandle:
    var f = lib.get_function[def(RuntimeHandle, Box3D) thin abi("C") -> OptionalBoxArrayHandle](
        "amrex_mojo_boxarray_create_from_box"
    )
    return f(runtime, domain)


def boxarray_destroy(ref lib: OwnedDLHandle, boxarray: BoxArrayHandle) raises:
    lib.call["amrex_mojo_boxarray_destroy"](boxarray)


def boxarray_max_size(ref lib: OwnedDLHandle, boxarray: BoxArrayHandle, max_size: IntVect3D) raises -> Int:
    var f = lib.get_function[def(BoxArrayHandle, IntVect3D) thin abi("C") -> c_int]("amrex_mojo_boxarray_max_size")
    return Int(f(boxarray, max_size))


def boxarray_size(ref lib: OwnedDLHandle, boxarray: BoxArrayHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_boxarray_size", c_int](boxarray))


def distmap_create_from_boxarray(
    ref lib: OwnedDLHandle,
    runtime: RuntimeHandle,
    boxarray: BoxArrayHandle,
) raises -> OptionalDistributionMappingHandle:
    return lib.call[
        "amrex_mojo_distmap_create_from_boxarray",
        OptionalDistributionMappingHandle,
    ](runtime, boxarray)


def distmap_destroy(ref lib: OwnedDLHandle, distmap: DistributionMappingHandle) raises:
    lib.call["amrex_mojo_distmap_destroy"](distmap)


def geometry_create(ref lib: OwnedDLHandle, runtime: RuntimeHandle, domain: Box3D) raises -> OptionalGeometryHandle:
    var f = lib.get_function[def(RuntimeHandle, Box3D) thin abi("C") -> OptionalGeometryHandle](
        "amrex_mojo_geometry_create"
    )
    return f(runtime, domain)


def geometry_create(
    ref lib: OwnedDLHandle,
    runtime: RuntimeHandle,
    domain: Box3D,
    real_box: RealBox3D,
    is_periodic: IntVect3D,
) raises -> OptionalGeometryHandle:
    var f = lib.get_function[def(RuntimeHandle, Box3D, RealBox3D, IntVect3D) thin abi("C") -> OptionalGeometryHandle](
        "amrex_mojo_geometry_create_with_real_box_and_periodicity"
    )
    return f(runtime, domain, real_box, is_periodic)


def geometry_destroy(ref lib: OwnedDLHandle, geometry: GeometryHandle) raises:
    lib.call["amrex_mojo_geometry_destroy"](geometry)


def multifab_create(
    ref lib: OwnedDLHandle,
    runtime: RuntimeHandle,
    boxarray: BoxArrayHandle,
    distmap: DistributionMappingHandle,
    ncomp: Int,
    ngrow: IntVect3D,
    datatype: Int = MULTIFAB_DATATYPE_FLOAT64,
) raises -> OptionalMultiFabHandle:
    var f = lib.get_function[
        def(
            RuntimeHandle,
            BoxArrayHandle,
            DistributionMappingHandle,
            c_int,
            IntVect3D,
            c_int,
            c_int,
        ) thin abi("C") -> OptionalMultiFabHandle
    ]("amrex_mojo_multifab_create_with_memory_and_datatype")
    return f(
        runtime,
        boxarray,
        distmap,
        c_int(ncomp),
        ngrow,
        c_int(0),
        c_int(datatype),
    )


def multifab_destroy(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises:
    lib.call["amrex_mojo_multifab_destroy"](multifab)


def multifab_ncomp(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_multifab_ncomp", c_int](multifab))


def multifab_datatype(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_multifab_datatype", c_int](multifab))


def multifab_memory_info(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises -> MultiFabMemoryInfo:
    var raw = List[c_int](length=6, fill=0)
    _ = lib.call["amrex_mojo_multifab_memory_info", c_int](multifab, raw.unsafe_ptr())
    return MultiFabMemoryInfo(
        requested_kind=Int(raw[0]),
        host_accessible=raw[1] != 0,
        device_accessible=raw[2] != 0,
        is_managed=raw[3] != 0,
        is_device=raw[4] != 0,
        is_pinned=raw[5] != 0,
    )


def multifab_set_val(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
) raises -> Int:
    return Int(
        lib.call["amrex_mojo_multifab_set_val", c_int](multifab, c_double(value), c_int(start_comp), c_int(ncomp))
    )


def multifab_tile_count(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_multifab_tile_count", c_int](multifab))


def multifab_tile_box(ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int) raises -> Box3D:
    var f = lib.get_function[def(MultiFabHandle, c_int) thin abi("C") -> Box3D]("amrex_mojo_multifab_tile_box")
    return f(multifab, c_int(tile_index))


def multifab_valid_box(ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int) raises -> Box3D:
    var f = lib.get_function[def(MultiFabHandle, c_int) thin abi("C") -> Box3D]("amrex_mojo_multifab_valid_box")
    return f(multifab, c_int(tile_index))


def mfiter_create(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises -> OptionalMFIterHandle:
    var out_handle = List[OptionalMFIterHandle](length=1, fill=None)
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


def mfiter_local_tile_index(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises -> Int:
    return Int(lib.call["amrex_mojo_mfiter_local_tile_index", c_int](mfiter))


def mfiter_tile_box(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises -> Box3D:
    var f = lib.get_function[def(MFIterHandle) thin abi("C") -> Box3D]("amrex_mojo_mfiter_tile_box")
    return f(mfiter)


def mfiter_valid_box(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises -> Box3D:
    var f = lib.get_function[def(MFIterHandle) thin abi("C") -> Box3D]("amrex_mojo_mfiter_valid_box")
    return f(mfiter)


def mfiter_fab_box(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises -> Box3D:
    var f = lib.get_function[def(MFIterHandle) thin abi("C") -> Box3D]("amrex_mojo_mfiter_fab_box")
    return f(mfiter)


def mfiter_growntile_box(ref lib: OwnedDLHandle, mfiter: MFIterHandle, ngrow: IntVect3D) raises -> Box3D:
    var f = lib.get_function[def(MFIterHandle, IntVect3D) thin abi("C") -> Box3D]("amrex_mojo_mfiter_growntile_box")
    return f(mfiter, ngrow)


def _mfiter_scalar_data_ptr[
    T: AmrexFloatingDtype,
    use_device_ptr: Bool,
    owner_origin: Origin[mut=True],
](
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> UnsafePointer[
    Scalar[T.dtype], owner_origin
]:
    var data: Optional[UnsafePointer[T.c_type, owner_origin]]
    comptime if use_device_ptr:
        data = T.mfiter_device_data_ptr[owner_origin](lib, multifab, mfiter)
    else:
        data = T.mfiter_host_data_ptr[owner_origin](lib, multifab, mfiter)
    if not data:
        raise Error(last_error_message(lib))
    return rebind[UnsafePointer[Scalar[T.dtype], owner_origin]](data.value())


def _array4_view_from_mfiter_impl[
    T: AmrexFloatingDtype,
    use_device_ptr: Bool,
    owner_origin: Origin[mut=True],
](ref lib: OwnedDLHandle, multifab: MultiFabHandle, mfiter: MFIterHandle,) raises -> Array4View[T, owner_origin]:
    var data_lo = InlineArray[c_int, 3](fill=0)
    var data_hi = InlineArray[c_int, 3](fill=0)
    var stride = InlineArray[Int64, 4](fill=0)
    var ncomp_raw = InlineArray[c_int, 1](fill=0)

    _ = lib.call["amrex_mojo_multifab_array4_metadata_for_mfiter", c_int](
        multifab,
        mfiter,
        data_lo.unsafe_ptr(),
        data_hi.unsafe_ptr(),
        stride.unsafe_ptr(),
        ncomp_raw.unsafe_ptr(),
    )

    var data = _mfiter_scalar_data_ptr[T, use_device_ptr, owner_origin](lib, multifab, mfiter)

    return Array4View[T, owner_origin](
        data=data,
        layout=Array4LayoutMetadata(
            lo_x=Int(data_lo[0]),
            lo_y=Int(data_lo[1]),
            lo_z=Int(data_lo[2]),
            hi_x=Int(data_hi[0]),
            hi_y=Int(data_hi[1]),
            hi_z=Int(data_hi[2]),
            stride_i=Int(stride[0]),
            stride_j=Int(stride[1]),
            stride_k=Int(stride[2]),
            stride_n=Int(stride[3]),
            ncomp=Int(ncomp_raw[0]),
        ),
    )


def _array4_view_from_mfiter[
    T: AmrexFloatingDtype, owner_origin: Origin[mut=True]
](ref lib: OwnedDLHandle, multifab: MultiFabHandle, mfiter: MFIterHandle,) raises -> Array4View[T, owner_origin]:
    return _array4_view_from_mfiter_impl[T, False, owner_origin](lib, multifab, mfiter)


def _device_array4_view_from_mfiter[
    T: AmrexFloatingDtype, owner_origin: Origin[mut=True]
](ref lib: OwnedDLHandle, multifab: MultiFabHandle, mfiter: MFIterHandle,) raises -> Array4View[T, owner_origin]:
    return _array4_view_from_mfiter_impl[T, True, owner_origin](lib, multifab, mfiter)


def array4_view_from_mfiter[
    T: AmrexFloatingDtype,
    owner_origin: Origin[mut=True],
](ref lib: OwnedDLHandle, multifab: MultiFabHandle, mfiter: MFIterHandle,) raises -> Array4View[T, owner_origin]:
    return _array4_view_from_mfiter[T, owner_origin](lib, multifab, mfiter)


def device_array4_view_from_mfiter[
    T: AmrexFloatingDtype
](ref lib: OwnedDLHandle, multifab: MultiFabHandle, mfiter: MFIterHandle,) raises -> Array4View[T, MutUnsafeAnyOrigin]:
    return _device_array4_view_from_mfiter[T, MutUnsafeAnyOrigin](lib, multifab, mfiter)


def device_array4_view_from_mfiter_as_origin[
    T: AmrexFloatingDtype,
    owner_origin: Origin[mut=True],
](ref lib: OwnedDLHandle, multifab: MultiFabHandle, mfiter: MFIterHandle,) raises -> Array4View[T, owner_origin]:
    return _device_array4_view_from_mfiter[T, owner_origin](lib, multifab, mfiter)


def multifab_sum(ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int) raises -> Float64:
    return lib.call["amrex_mojo_multifab_sum", c_double](multifab, c_int(comp))


def boxarray_box(ref lib: OwnedDLHandle, boxarray: BoxArrayHandle, index: Int) raises -> Box3D:
    var f = lib.get_function[def(BoxArrayHandle, c_int) thin abi("C") -> Box3D]("amrex_mojo_boxarray_box")
    return f(boxarray, c_int(index))


def geometry_domain(ref lib: OwnedDLHandle, geometry: GeometryHandle) raises -> Box3D:
    var f = lib.get_function[def(GeometryHandle) thin abi("C") -> Box3D]("amrex_mojo_geometry_domain")
    return f(geometry)


def geometry_prob_domain(ref lib: OwnedDLHandle, geometry: GeometryHandle) raises -> RealBox3D:
    var f = lib.get_function[def(GeometryHandle) thin abi("C") -> RealBox3D]("amrex_mojo_geometry_prob_domain")
    return f(geometry)


def geometry_cell_size(ref lib: OwnedDLHandle, geometry: GeometryHandle) raises -> RealVect3D:
    var f = lib.get_function[def(GeometryHandle) thin abi("C") -> RealVect3D]("amrex_mojo_geometry_cell_size")
    return f(geometry)


def geometry_periodicity(ref lib: OwnedDLHandle, geometry: GeometryHandle) raises -> IntVect3D:
    var f = lib.get_function[def(GeometryHandle) thin abi("C") -> IntVect3D]("amrex_mojo_geometry_periodicity")
    return f(geometry)


def multifab_min(ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int) raises -> Float64:
    return lib.call["amrex_mojo_multifab_min", c_double](multifab, c_int(comp))


def multifab_max(ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int) raises -> Float64:
    return lib.call["amrex_mojo_multifab_max", c_double](multifab, c_int(comp))


def multifab_norm0(ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int) raises -> Float64:
    return lib.call["amrex_mojo_multifab_norm0", c_double](multifab, c_int(comp))


def multifab_norm1(ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int) raises -> Float64:
    return lib.call["amrex_mojo_multifab_norm1", c_double](multifab, c_int(comp))


def multifab_norm2(ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int) raises -> Float64:
    return lib.call["amrex_mojo_multifab_norm2", c_double](multifab, c_int(comp))


def multifab_plus(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    var f = lib.get_function[def(MultiFabHandle, c_double, c_int, c_int, IntVect3D) thin abi("C") -> c_int](
        "amrex_mojo_multifab_plus"
    )
    return Int(f(multifab, c_double(value), c_int(start_comp), c_int(ncomp), ngrow))


def multifab_mult(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    var f = lib.get_function[def(MultiFabHandle, c_double, c_int, c_int, IntVect3D) thin abi("C") -> c_int](
        "amrex_mojo_multifab_mult"
    )
    return Int(f(multifab, c_double(value), c_int(start_comp), c_int(ncomp), ngrow))


def multifab_copy(
    ref lib: OwnedDLHandle,
    dst_multifab: MultiFabHandle,
    src_multifab: MultiFabHandle,
    src_comp: Int,
    dst_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    var f = lib.get_function[
        def(
            MultiFabHandle,
            MultiFabHandle,
            c_int,
            c_int,
            c_int,
            c_int,
            c_int,
            c_int,
        ) thin abi("C") -> c_int
    ]("amrex_mojo_multifab_copy_xyz")
    return Int(
        f(
            dst_multifab,
            src_multifab,
            c_int(src_comp),
            c_int(dst_comp),
            c_int(ncomp),
            ngrow.x,
            ngrow.y,
            ngrow.z,
        )
    )


def multifab_parallel_copy(
    ref lib: OwnedDLHandle,
    dst_multifab: MultiFabHandle,
    src_multifab: MultiFabHandle,
    geometry: GeometryHandle,
    src_comp: Int,
    dst_comp: Int,
    ncomp: Int,
    src_ngrow: IntVect3D,
    dst_ngrow: IntVect3D,
) raises -> Int:
    var f = lib.get_function[
        def(
            MultiFabHandle,
            MultiFabHandle,
            GeometryHandle,
            c_int,
            c_int,
            c_int,
            c_int,
            c_int,
            c_int,
            c_int,
            c_int,
            c_int,
        ) thin abi("C") -> c_int
    ]("amrex_mojo_multifab_parallel_copy_xyz")
    return Int(
        f(
            dst_multifab,
            src_multifab,
            geometry,
            c_int(src_comp),
            c_int(dst_comp),
            c_int(ncomp),
            src_ngrow.x,
            src_ngrow.y,
            src_ngrow.z,
            dst_ngrow.x,
            dst_ngrow.y,
            dst_ngrow.z,
        )
    )


def multifab_fill_boundary(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    geometry: GeometryHandle,
    start_comp: Int,
    ncomp: Int,
    cross: Bool = False,
) raises -> Int:
    return Int(
        lib.call["amrex_mojo_multifab_fill_boundary", c_int](
            multifab,
            geometry,
            c_int(start_comp),
            c_int(ncomp),
            c_int(1 if cross else 0),
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


def parmparse_create(ref lib: OwnedDLHandle, runtime: RuntimeHandle, prefix: String) raises -> OptionalParmParseHandle:
    var prefix_owned = prefix
    if prefix_owned.byte_length() == 0:
        var prefix_null: OptionalCStringHandle = None
        return lib.call["amrex_mojo_parmparse_create", OptionalParmParseHandle](runtime, prefix_null)
    return lib.call["amrex_mojo_parmparse_create", OptionalParmParseHandle](
        runtime, prefix_owned.as_c_string_slice().unsafe_ptr()
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


def parmparse_query_int(
    ref lib: OwnedDLHandle, parmparse: ParmParseHandle, name: String
) raises -> ParmParseIntQueryResult:
    var name_owned = name
    var out_value = InlineArray[c_int, 1](fill=0)
    var out_found = InlineArray[c_int, 1](fill=0)
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


def parmparse_query_real(
    ref lib: OwnedDLHandle, parmparse: ParmParseHandle, name: String
) raises -> ParmParseRealQueryResult:
    var name_owned = name
    var out_value = InlineArray[c_double, 1](fill=0.0)
    var out_found = InlineArray[c_int, 1](fill=0)
    var status = Int(
        lib.call["amrex_mojo_parmparse_query_real", c_int](
            parmparse,
            name_owned.as_c_string_slice().unsafe_ptr(),
            out_value.unsafe_ptr(),
            out_found.unsafe_ptr(),
        )
    )
    return ParmParseRealQueryResult(
        status=status,
        found=out_found[0] != 0,
        value=Float64(out_value[0]),
    )
