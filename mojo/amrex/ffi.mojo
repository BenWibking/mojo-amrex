from std.collections import List
from std.builtin.device_passable import DevicePassable
from std.ffi import OwnedDLHandle, c_char, c_double, c_float, c_int


comptime RuntimeHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime BoxArrayHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime DistributionMappingHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime GeometryHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime MultiFabHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime MFIterHandle = UnsafePointer[NoneType, MutExternalOrigin]
comptime ParmParseHandle = UnsafePointer[NoneType, MutExternalOrigin]

comptime GPU_BACKEND_NONE = 0
comptime GPU_BACKEND_CUDA = 1
comptime GPU_BACKEND_HIP = 2

comptime MULTIFAB_DATATYPE_FLOAT64 = 0
comptime MULTIFAB_DATATYPE_FLOAT32 = 1

comptime LastErrorMessageFn = def() abi("C") thin -> UnsafePointer[
    c_char, ImmutExternalOrigin
]
comptime AbiVersionFn = def() abi("C") thin -> c_int
comptime RuntimeCreateDefaultFn = def() abi("C") thin -> RuntimeHandle
comptime RuntimeCreateDefaultOnDeviceFn = def(c_int) abi("C") thin -> RuntimeHandle
comptime RuntimeDestroyFn = def(RuntimeHandle) abi("C") thin -> NoneType
comptime RuntimeInitializedFn = def(RuntimeHandle) abi("C") thin -> c_int
comptime GpuBackendFn = def() abi("C") thin -> c_int
comptime GpuDeviceIdFn = def() abi("C") thin -> c_int
comptime GpuNumStreamsFn = def() abi("C") thin -> c_int
comptime GpuSetStreamIndexFn = def(c_int) abi("C") thin -> c_int
comptime GpuResetStreamFn = def() abi("C") thin -> NoneType
comptime GpuStreamFn = def() abi("C") thin -> UnsafePointer[
    NoneType, MutExternalOrigin
]
comptime GpuStreamSynchronizeActiveFn = def() abi("C") thin -> c_int
comptime ParallelNprocsFn = def() abi("C") thin -> c_int
comptime ParallelMyprocFn = def() abi("C") thin -> c_int
comptime ParallelIoprocessorFn = def() abi("C") thin -> c_int
comptime ParallelIoprocessorNumberFn = def() abi("C") thin -> c_int
comptime BoxArrayCreateFromBoundsFn = def(
    RuntimeHandle, c_int, c_int, c_int, c_int, c_int, c_int, c_int, c_int, c_int
) abi("C") thin -> BoxArrayHandle
comptime BoxArrayDestroyFn = def(BoxArrayHandle) abi("C") thin -> NoneType
comptime BoxArrayMaxSizeXyzFn = def(
    BoxArrayHandle, c_int, c_int, c_int
) abi("C") thin -> c_int
comptime BoxArraySizeFn = def(BoxArrayHandle) abi("C") thin -> c_int
comptime DistmapCreateFromBoxarrayFn = def(
    RuntimeHandle, BoxArrayHandle
) abi("C") thin -> DistributionMappingHandle
comptime DistmapDestroyFn = def(DistributionMappingHandle) abi("C") thin -> NoneType
comptime GeometryCreateFromBoundsFn = def(
    RuntimeHandle, c_int, c_int, c_int, c_int, c_int, c_int, c_int, c_int, c_int
) abi("C") thin -> GeometryHandle
comptime GeometryCreateFromBoundsWithRealBoxAndPeriodicityFn = def(
    RuntimeHandle,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
    c_double,
    c_double,
    c_double,
    c_double,
    c_double,
    c_double,
    c_int,
    c_int,
    c_int,
) abi("C") thin -> GeometryHandle
comptime GeometryDestroyFn = def(GeometryHandle) abi("C") thin -> NoneType
comptime MultifabCreateWithMemoryAndDatatypeXyzFn = def(
    RuntimeHandle,
    BoxArrayHandle,
    DistributionMappingHandle,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
    c_int,
) abi("C") thin -> MultiFabHandle
comptime MultifabDestroyFn = def(MultiFabHandle) abi("C") thin -> NoneType
comptime MultifabNcompFn = def(MultiFabHandle) abi("C") thin -> c_int
comptime MultifabDatatypeFn = def(MultiFabHandle) abi("C") thin -> c_int
comptime MultifabSetValFn = def(
    MultiFabHandle, c_double, c_int, c_int
) abi("C") thin -> c_int
comptime MultifabTileCountFn = def(MultiFabHandle) abi("C") thin -> c_int
comptime MultifabTileBoxFn = def(MultiFabHandle, c_int) abi("C") thin -> Box3D
comptime MultifabValidBoxFn = def(MultiFabHandle, c_int) abi("C") thin -> Box3D
comptime MfiterDestroyFn = def(MFIterHandle) abi("C") thin -> NoneType
comptime MfiterIsValidFn = def(MFIterHandle) abi("C") thin -> c_int
comptime MfiterNextFn = def(MFIterHandle) abi("C") thin -> c_int
comptime MfiterIndexFn = def(MFIterHandle) abi("C") thin -> c_int
comptime MfiterLocalTileIndexFn = def(MFIterHandle) abi("C") thin -> c_int
comptime MultifabSumFn = def(MultiFabHandle, c_int) abi("C") thin -> c_double
comptime MultifabMinFn = def(MultiFabHandle, c_int) abi("C") thin -> c_double
comptime MultifabMaxFn = def(MultiFabHandle, c_int) abi("C") thin -> c_double
comptime MultifabNorm0Fn = def(MultiFabHandle, c_int) abi("C") thin -> c_double
comptime MultifabNorm1Fn = def(MultiFabHandle, c_int) abi("C") thin -> c_double
comptime MultifabNorm2Fn = def(MultiFabHandle, c_int) abi("C") thin -> c_double
comptime MultifabPlusFn = def(
    MultiFabHandle, c_double, c_int, c_int, IntVect3D
) abi("C") thin -> c_int
comptime MultifabMultFn = def(
    MultiFabHandle, c_double, c_int, c_int, IntVect3D
) abi("C") thin -> c_int
comptime MultifabCopyFn = def(
    MultiFabHandle, MultiFabHandle, c_int, c_int, c_int, IntVect3D
) abi("C") thin -> c_int
comptime MultifabParallelCopyFn = def(
    MultiFabHandle,
    MultiFabHandle,
    GeometryHandle,
    c_int,
    c_int,
    c_int,
    IntVect3D,
    IntVect3D,
) abi("C") thin -> c_int
comptime MultifabFillBoundaryFn = def(
    MultiFabHandle, GeometryHandle, c_int, c_int, c_int
) abi("C") thin -> c_int
comptime ParmparseDestroyFn = def(ParmParseHandle) abi("C") thin -> NoneType


struct AmrexFunctionCache(Movable):
    var last_error_message_fn: LastErrorMessageFn
    var abi_version_fn: AbiVersionFn
    var runtime_create_default_fn: RuntimeCreateDefaultFn
    var runtime_create_default_on_device_fn: RuntimeCreateDefaultOnDeviceFn
    var runtime_destroy_fn: RuntimeDestroyFn
    var runtime_initialized_fn: RuntimeInitializedFn
    var gpu_backend_fn: GpuBackendFn
    var gpu_device_id_fn: GpuDeviceIdFn
    var gpu_num_streams_fn: GpuNumStreamsFn
    var gpu_set_stream_index_fn: GpuSetStreamIndexFn
    var gpu_reset_stream_fn: GpuResetStreamFn
    var gpu_stream_fn: GpuStreamFn
    var gpu_stream_synchronize_active_fn: GpuStreamSynchronizeActiveFn
    var parallel_nprocs_fn: ParallelNprocsFn
    var parallel_myproc_fn: ParallelMyprocFn
    var parallel_ioprocessor_fn: ParallelIoprocessorFn
    var parallel_ioprocessor_number_fn: ParallelIoprocessorNumberFn
    var boxarray_create_from_bounds_fn: BoxArrayCreateFromBoundsFn
    var boxarray_destroy_fn: BoxArrayDestroyFn
    var boxarray_max_size_xyz_fn: BoxArrayMaxSizeXyzFn
    var boxarray_size_fn: BoxArraySizeFn
    var distmap_create_from_boxarray_fn: DistmapCreateFromBoxarrayFn
    var distmap_destroy_fn: DistmapDestroyFn
    var geometry_create_from_bounds_fn: GeometryCreateFromBoundsFn
    var geometry_create_with_real_box_fn:
        GeometryCreateFromBoundsWithRealBoxAndPeriodicityFn
    var geometry_destroy_fn: GeometryDestroyFn
    var multifab_create_fn: MultifabCreateWithMemoryAndDatatypeXyzFn
    var multifab_destroy_fn: MultifabDestroyFn
    var multifab_ncomp_fn: MultifabNcompFn
    var multifab_datatype_fn: MultifabDatatypeFn
    var multifab_set_val_fn: MultifabSetValFn
    var multifab_tile_count_fn: MultifabTileCountFn
    var multifab_tile_box_fn: MultifabTileBoxFn
    var multifab_valid_box_fn: MultifabValidBoxFn
    var mfiter_destroy_fn: MfiterDestroyFn
    var mfiter_is_valid_fn: MfiterIsValidFn
    var mfiter_next_fn: MfiterNextFn
    var mfiter_index_fn: MfiterIndexFn
    var mfiter_local_tile_index_fn: MfiterLocalTileIndexFn
    var multifab_sum_fn: MultifabSumFn
    var multifab_min_fn: MultifabMinFn
    var multifab_max_fn: MultifabMaxFn
    var multifab_norm0_fn: MultifabNorm0Fn
    var multifab_norm1_fn: MultifabNorm1Fn
    var multifab_norm2_fn: MultifabNorm2Fn
    var multifab_plus_fn: MultifabPlusFn
    var multifab_mult_fn: MultifabMultFn
    var multifab_copy_fn: MultifabCopyFn
    var multifab_parallel_copy_fn: MultifabParallelCopyFn
    var multifab_fill_boundary_fn: MultifabFillBoundaryFn
    var parmparse_destroy_fn: ParmparseDestroyFn

    def __init__(out self, ref lib: OwnedDLHandle) raises:
        self.last_error_message_fn = lib.get_function[LastErrorMessageFn](
            "amrex_mojo_last_error_message"
        )
        self.abi_version_fn = lib.get_function[AbiVersionFn]("amrex_mojo_abi_version")
        self.runtime_create_default_fn = lib.get_function[RuntimeCreateDefaultFn](
            "amrex_mojo_runtime_create_default"
        )
        self.runtime_create_default_on_device_fn = lib.get_function[
            RuntimeCreateDefaultOnDeviceFn
        ]("amrex_mojo_runtime_create_default_on_device")
        self.runtime_destroy_fn = lib.get_function[RuntimeDestroyFn](
            "amrex_mojo_runtime_destroy"
        )
        self.runtime_initialized_fn = lib.get_function[RuntimeInitializedFn](
            "amrex_mojo_runtime_initialized"
        )
        self.gpu_backend_fn = lib.get_function[GpuBackendFn]("amrex_mojo_gpu_backend")
        self.gpu_device_id_fn = lib.get_function[GpuDeviceIdFn](
            "amrex_mojo_gpu_device_id"
        )
        self.gpu_num_streams_fn = lib.get_function[GpuNumStreamsFn](
            "amrex_mojo_gpu_num_streams"
        )
        self.gpu_set_stream_index_fn = lib.get_function[GpuSetStreamIndexFn](
            "amrex_mojo_gpu_set_stream_index"
        )
        self.gpu_reset_stream_fn = lib.get_function[GpuResetStreamFn](
            "amrex_mojo_gpu_reset_stream"
        )
        self.gpu_stream_fn = lib.get_function[GpuStreamFn]("amrex_mojo_gpu_stream")
        self.gpu_stream_synchronize_active_fn = lib.get_function[
            GpuStreamSynchronizeActiveFn
        ]("amrex_mojo_gpu_stream_synchronize_active")
        self.parallel_nprocs_fn = lib.get_function[ParallelNprocsFn](
            "amrex_mojo_parallel_nprocs"
        )
        self.parallel_myproc_fn = lib.get_function[ParallelMyprocFn](
            "amrex_mojo_parallel_myproc"
        )
        self.parallel_ioprocessor_fn = lib.get_function[ParallelIoprocessorFn](
            "amrex_mojo_parallel_ioprocessor"
        )
        self.parallel_ioprocessor_number_fn = lib.get_function[
            ParallelIoprocessorNumberFn
        ]("amrex_mojo_parallel_ioprocessor_number")
        self.boxarray_create_from_bounds_fn = lib.get_function[
            BoxArrayCreateFromBoundsFn
        ]("amrex_mojo_boxarray_create_from_bounds")
        self.boxarray_destroy_fn = lib.get_function[BoxArrayDestroyFn](
            "amrex_mojo_boxarray_destroy"
        )
        self.boxarray_max_size_xyz_fn = lib.get_function[BoxArrayMaxSizeXyzFn](
            "amrex_mojo_boxarray_max_size_xyz"
        )
        self.boxarray_size_fn = lib.get_function[BoxArraySizeFn](
            "amrex_mojo_boxarray_size"
        )
        self.distmap_create_from_boxarray_fn = lib.get_function[
            DistmapCreateFromBoxarrayFn
        ]("amrex_mojo_distmap_create_from_boxarray")
        self.distmap_destroy_fn = lib.get_function[DistmapDestroyFn](
            "amrex_mojo_distmap_destroy"
        )
        self.geometry_create_from_bounds_fn = lib.get_function[
            GeometryCreateFromBoundsFn
        ]("amrex_mojo_geometry_create_from_bounds")
        self.geometry_create_with_real_box_fn = lib.get_function[
            GeometryCreateFromBoundsWithRealBoxAndPeriodicityFn
        ]("amrex_mojo_geometry_create_from_bounds_with_real_box_and_periodicity")
        self.geometry_destroy_fn = lib.get_function[GeometryDestroyFn](
            "amrex_mojo_geometry_destroy"
        )
        self.multifab_create_fn = lib.get_function[
            MultifabCreateWithMemoryAndDatatypeXyzFn
        ]("amrex_mojo_multifab_create_with_memory_and_datatype_xyz")
        self.multifab_destroy_fn = lib.get_function[MultifabDestroyFn](
            "amrex_mojo_multifab_destroy"
        )
        self.multifab_ncomp_fn = lib.get_function[MultifabNcompFn](
            "amrex_mojo_multifab_ncomp"
        )
        self.multifab_datatype_fn = lib.get_function[MultifabDatatypeFn](
            "amrex_mojo_multifab_datatype"
        )
        self.multifab_set_val_fn = lib.get_function[MultifabSetValFn](
            "amrex_mojo_multifab_set_val"
        )
        self.multifab_tile_count_fn = lib.get_function[MultifabTileCountFn](
            "amrex_mojo_multifab_tile_count"
        )
        self.multifab_tile_box_fn = lib.get_function[MultifabTileBoxFn](
            "amrex_mojo_multifab_tile_box"
        )
        self.multifab_valid_box_fn = lib.get_function[MultifabValidBoxFn](
            "amrex_mojo_multifab_valid_box"
        )
        self.mfiter_destroy_fn = lib.get_function[MfiterDestroyFn](
            "amrex_mojo_mfiter_destroy"
        )
        self.mfiter_is_valid_fn = lib.get_function[MfiterIsValidFn](
            "amrex_mojo_mfiter_is_valid"
        )
        self.mfiter_next_fn = lib.get_function[MfiterNextFn]("amrex_mojo_mfiter_next")
        self.mfiter_index_fn = lib.get_function[MfiterIndexFn]("amrex_mojo_mfiter_index")
        self.mfiter_local_tile_index_fn = lib.get_function[
            MfiterLocalTileIndexFn
        ]("amrex_mojo_mfiter_local_tile_index")
        self.multifab_sum_fn = lib.get_function[MultifabSumFn]("amrex_mojo_multifab_sum")
        self.multifab_min_fn = lib.get_function[MultifabMinFn]("amrex_mojo_multifab_min")
        self.multifab_max_fn = lib.get_function[MultifabMaxFn]("amrex_mojo_multifab_max")
        self.multifab_norm0_fn = lib.get_function[MultifabNorm0Fn](
            "amrex_mojo_multifab_norm0"
        )
        self.multifab_norm1_fn = lib.get_function[MultifabNorm1Fn](
            "amrex_mojo_multifab_norm1"
        )
        self.multifab_norm2_fn = lib.get_function[MultifabNorm2Fn](
            "amrex_mojo_multifab_norm2"
        )
        self.multifab_plus_fn = lib.get_function[MultifabPlusFn](
            "amrex_mojo_multifab_plus"
        )
        self.multifab_mult_fn = lib.get_function[MultifabMultFn](
            "amrex_mojo_multifab_mult"
        )
        self.multifab_copy_fn = lib.get_function[MultifabCopyFn](
            "amrex_mojo_multifab_copy"
        )
        self.multifab_parallel_copy_fn = lib.get_function[
            MultifabParallelCopyFn
        ]("amrex_mojo_multifab_parallel_copy")
        self.multifab_fill_boundary_fn = lib.get_function[MultifabFillBoundaryFn](
            "amrex_mojo_multifab_fill_boundary"
        )
        self.parmparse_destroy_fn = lib.get_function[ParmparseDestroyFn](
            "amrex_mojo_parmparse_destroy"
        )


def init_device_passable_value[
    T: TrivialRegisterPassable,
    mut_origin: Origin[mut=True],
](value: T, target: UnsafePointer[NoneType, mut_origin]):
    target.bitcast[T]().init_pointee_copy(value)


@fieldwise_init
struct IntVect3D(DevicePassable, TrivialRegisterPassable):
    comptime device_type = Self

    var x: c_int
    var y: c_int
    var z: c_int

    def _to_device_type[
        mut_origin: Origin[mut=True]
    ](self, target: UnsafePointer[NoneType, mut_origin],):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("IntVect3D")


@fieldwise_init
struct Box3D(DevicePassable, TrivialRegisterPassable):
    comptime device_type = Self

    var small_end: IntVect3D
    var big_end: IntVect3D
    var nodal: IntVect3D

    def _to_device_type[
        mut_origin: Origin[mut=True]
    ](self, target: UnsafePointer[NoneType, mut_origin],):
        init_device_passable_value(self, target)

    @staticmethod
    def get_type_name() -> String:
        return String("Box3D")


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
struct ParmParseRealQueryResult(Copyable):
    var status: Int
    var found: Bool
    var value: Float64


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
struct MultiFabMemoryInfo(Copyable):
    var requested_kind: Int
    var host_accessible: Bool
    var device_accessible: Bool
    var is_managed: Bool
    var is_device: Bool
    var is_pinned: Bool


@fieldwise_init
struct RawArray4Metadata(Copyable):
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


@fieldwise_init
struct RawTileMetadata(Copyable):
    var tile_box: Box3D
    var valid_box: Box3D
    var array: RawArray4Metadata


@fieldwise_init
struct Array4F64View[origin: Origin[mut=True]](
    DevicePassable, TrivialRegisterPassable
):
    comptime device_type = Array4F64View[MutAnyOrigin]

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

    def device_view(self) -> Self.device_type:
        return Array4F64View[MutAnyOrigin](
            data=UnsafePointer[c_double, MutAnyOrigin](self.data),
            lo_x=self.lo_x,
            lo_y=self.lo_y,
            lo_z=self.lo_z,
            hi_x=self.hi_x,
            hi_y=self.hi_y,
            hi_z=self.hi_z,
            stride_i=self.stride_i,
            stride_j=self.stride_j,
            stride_k=self.stride_k,
            stride_n=self.stride_n,
            ncomp=self.ncomp,
        )

    def _to_device_type[
        mut_origin: Origin[mut=True]
    ](self, target: UnsafePointer[NoneType, mut_origin],):
        init_device_passable_value(self.device_view(), target)

    @staticmethod
    def get_type_name() -> String:
        return String("Array4F64View")

    def offset(self, i: Int, j: Int, k: Int, comp: Int = 0) -> Int:
        return (
            (i - Int(self.lo_x)) * Int(self.stride_i)
            + (j - Int(self.lo_y)) * Int(self.stride_j)
            + (k - Int(self.lo_z)) * Int(self.stride_k)
            + comp * Int(self.stride_n)
        )

    def __getitem__(self, i: Int, j: Int, k: Int) -> Float64:
        return self.data[self.offset(i, j, k)]

    def __getitem__(self, i: Int, j: Int, k: Int, comp: Int) -> Float64:
        return self.data[self.offset(i, j, k, comp)]

    def __setitem__(self, i: Int, j: Int, k: Int, value: Float64):
        self.data[self.offset(i, j, k)] = value

    def __setitem__(self, i: Int, j: Int, k: Int, comp: Int, value: Float64):
        self.data[self.offset(i, j, k, comp)] = value

    def fill(self, box: Box3D, value: Float64, comp: Int = 0):
        for k in range(Int(box.small_end.z), Int(box.big_end.z) + 1):
            for j in range(Int(box.small_end.y), Int(box.big_end.y) + 1):
                for i in range(Int(box.small_end.x), Int(box.big_end.x) + 1):
                    self[i, j, k, comp] = value


@fieldwise_init
struct Array4F32View[origin: Origin[mut=True]](
    DevicePassable, TrivialRegisterPassable
):
    comptime device_type = Array4F32View[MutAnyOrigin]

    var data: UnsafePointer[c_float, Self.origin]
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

    def device_view(self) -> Self.device_type:
        return Array4F32View[MutAnyOrigin](
            data=UnsafePointer[c_float, MutAnyOrigin](self.data),
            lo_x=self.lo_x,
            lo_y=self.lo_y,
            lo_z=self.lo_z,
            hi_x=self.hi_x,
            hi_y=self.hi_y,
            hi_z=self.hi_z,
            stride_i=self.stride_i,
            stride_j=self.stride_j,
            stride_k=self.stride_k,
            stride_n=self.stride_n,
            ncomp=self.ncomp,
        )

    def _to_device_type[
        mut_origin: Origin[mut=True]
    ](self, target: UnsafePointer[NoneType, mut_origin],):
        init_device_passable_value(self.device_view(), target)

    @staticmethod
    def get_type_name() -> String:
        return String("Array4F32View")

    def offset(self, i: Int, j: Int, k: Int, comp: Int = 0) -> Int:
        return (
            (i - Int(self.lo_x)) * Int(self.stride_i)
            + (j - Int(self.lo_y)) * Int(self.stride_j)
            + (k - Int(self.lo_z)) * Int(self.stride_k)
            + comp * Int(self.stride_n)
        )

    def __getitem__(self, i: Int, j: Int, k: Int) -> Float32:
        return self.data[self.offset(i, j, k)]

    def __getitem__(self, i: Int, j: Int, k: Int, comp: Int) -> Float32:
        return self.data[self.offset(i, j, k, comp)]

    def __setitem__(self, i: Int, j: Int, k: Int, value: Float32):
        self.data[self.offset(i, j, k)] = value

    def __setitem__(self, i: Int, j: Int, k: Int, comp: Int, value: Float32):
        self.data[self.offset(i, j, k, comp)] = value

    def fill(self, box: Box3D, value: Float32, comp: Int = 0):
        for k in range(Int(box.small_end.z), Int(box.big_end.z) + 1):
            for j in range(Int(box.small_end.y), Int(box.big_end.y) + 1):
                for i in range(Int(box.small_end.x), Int(box.big_end.x) + 1):
                    self[i, j, k, comp] = value


@fieldwise_init
struct TileF64View[origin: Origin[mut=True]](
    DevicePassable, TrivialRegisterPassable
):
    comptime device_type = TileF64View[MutAnyOrigin]

    var tile_box: Box3D
    var valid_box: Box3D
    var array_view: Array4F64View[Self.origin]

    def device_view(self) -> Self.device_type:
        return TileF64View[MutAnyOrigin](
            tile_box=self.tile_box.copy(),
            valid_box=self.valid_box.copy(),
            array_view=self.array_view.device_view(),
        )

    def _to_device_type[
        mut_origin: Origin[mut=True]
    ](self, target: UnsafePointer[NoneType, mut_origin],):
        init_device_passable_value(self.device_view(), target)

    @staticmethod
    def get_type_name() -> String:
        return String("TileF64View")

    def array(self) -> Array4F64View[Self.origin]:
        return self.array_view.copy()

    def fill(self, value: Float64, comp: Int = 0):
        self.array_view.fill(self.tile_box, value, comp)


@fieldwise_init
struct TileF32View[origin: Origin[mut=True]](
    DevicePassable, TrivialRegisterPassable
):
    comptime device_type = TileF32View[MutAnyOrigin]

    var tile_box: Box3D
    var valid_box: Box3D
    var array_view: Array4F32View[Self.origin]

    def device_view(self) -> Self.device_type:
        return TileF32View[MutAnyOrigin](
            tile_box=self.tile_box.copy(),
            valid_box=self.valid_box.copy(),
            array_view=self.array_view.device_view(),
        )

    def _to_device_type[
        mut_origin: Origin[mut=True]
    ](self, target: UnsafePointer[NoneType, mut_origin],):
        init_device_passable_value(self.device_view(), target)

    @staticmethod
    def get_type_name() -> String:
        return String("TileF32View")

    def array(self) -> Array4F32View[Self.origin]:
        return self.array_view.copy()

    def fill(self, value: Float32, comp: Int = 0):
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


def last_error_message(ref lib: OwnedDLHandle) raises -> String:
    var last_error_message_fn = lib.get_function[LastErrorMessageFn](
        "amrex_mojo_last_error_message"
    )
    var message = last_error_message_fn()
    if not message:
        return String("AMReX call failed.")
    return String(unsafe_from_utf8_ptr=message)


def abi_version(ref lib: OwnedDLHandle) raises -> Int:
    var abi_version_fn = lib.get_function[AbiVersionFn]("amrex_mojo_abi_version")
    return Int(abi_version_fn())


def runtime_create(ref lib: OwnedDLHandle) raises -> RuntimeHandle:
    var runtime_create_fn = lib.get_function[RuntimeCreateDefaultFn](
        "amrex_mojo_runtime_create_default"
    )
    return runtime_create_fn()


def runtime_create(
    ref lib: OwnedDLHandle, device_id: Int
) raises -> RuntimeHandle:
    var runtime_create_on_device_fn = lib.get_function[
        RuntimeCreateDefaultOnDeviceFn
    ]("amrex_mojo_runtime_create_default_on_device")
    return runtime_create_on_device_fn(c_int(device_id))


def runtime_create(
    ref lib: OwnedDLHandle,
    argv: List[String],
    use_parmparse: Bool = False,
) raises -> RuntimeHandle:
    # Keep `.call[...]` here: typed indirect calls reject the local-origin
    # argv pointer list where this path needs `UnsafePointer[..., MutAnyOrigin]`.
    var argc = len(argv)
    if argc == 0:
        return lib.call["amrex_mojo_runtime_create", RuntimeHandle](
            c_int(0),
            UnsafePointer[UnsafePointer[c_char, MutAnyOrigin], MutAnyOrigin](),
            c_int(1 if use_parmparse else 0),
        )

    var argv_storage = List[String](length=argc, fill=String(""))
    for i in range(argc):
        argv_storage[i] = argv[i].copy()

    var first_ptr = argv_storage[0].as_c_string_slice().unsafe_ptr()
    var argv_ptrs = List[type_of(first_ptr)](length=argc, fill=first_ptr)
    for i in range(1, argc):
        argv_ptrs[i] = argv_storage[i].as_c_string_slice().unsafe_ptr()

    return lib.call["amrex_mojo_runtime_create", RuntimeHandle](
        c_int(argc),
        argv_ptrs.unsafe_ptr(),
        c_int(1 if use_parmparse else 0),
    )


def runtime_create(
    ref lib: OwnedDLHandle,
    argv: List[String],
    use_parmparse: Bool,
    device_id: Int,
) raises -> RuntimeHandle:
    # Keep `.call[...]` here: typed indirect calls reject the local-origin
    # argv pointer list where this path needs `UnsafePointer[..., MutAnyOrigin]`.
    var argc = len(argv)
    if argc == 0:
        return lib.call[
            "amrex_mojo_runtime_create_on_device",
            RuntimeHandle,
        ](
            c_int(0),
            UnsafePointer[UnsafePointer[c_char, MutAnyOrigin], MutAnyOrigin](),
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
        RuntimeHandle,
    ](
        c_int(argc),
        argv_ptrs.unsafe_ptr(),
        c_int(1 if use_parmparse else 0),
        c_int(device_id),
    )


def runtime_destroy(ref lib: OwnedDLHandle, runtime: RuntimeHandle) raises:
    var runtime_destroy_fn = lib.get_function[RuntimeDestroyFn](
        "amrex_mojo_runtime_destroy"
    )
    runtime_destroy_fn(runtime)


def runtime_initialized(
    ref lib: OwnedDLHandle, runtime: RuntimeHandle
) raises -> Bool:
    var runtime_initialized_fn = lib.get_function[RuntimeInitializedFn](
        "amrex_mojo_runtime_initialized"
    )
    return runtime_initialized_fn(runtime) != 0


def gpu_backend(ref lib: OwnedDLHandle) raises -> Int:
    var gpu_backend_fn = lib.get_function[GpuBackendFn]("amrex_mojo_gpu_backend")
    return Int(gpu_backend_fn())


def gpu_device_id(ref lib: OwnedDLHandle) raises -> Int:
    var gpu_device_id_fn = lib.get_function[GpuDeviceIdFn](
        "amrex_mojo_gpu_device_id"
    )
    return Int(gpu_device_id_fn())


def gpu_num_streams(ref lib: OwnedDLHandle) raises -> Int:
    var gpu_num_streams_fn = lib.get_function[GpuNumStreamsFn](
        "amrex_mojo_gpu_num_streams"
    )
    return Int(gpu_num_streams_fn())


def gpu_set_stream_index(
    ref lib: OwnedDLHandle, stream_index: Int
) raises -> Int:
    var gpu_set_stream_index_fn = lib.get_function[GpuSetStreamIndexFn](
        "amrex_mojo_gpu_set_stream_index"
    )
    return Int(gpu_set_stream_index_fn(c_int(stream_index)))


def gpu_reset_stream(ref lib: OwnedDLHandle) raises:
    var gpu_reset_stream_fn = lib.get_function[GpuResetStreamFn](
        "amrex_mojo_gpu_reset_stream"
    )
    gpu_reset_stream_fn()


def gpu_stream(
    ref lib: OwnedDLHandle,
) raises -> UnsafePointer[NoneType, MutExternalOrigin]:
    var gpu_stream_fn = lib.get_function[GpuStreamFn]("amrex_mojo_gpu_stream")
    return gpu_stream_fn()


def gpu_stream_synchronize_active(ref lib: OwnedDLHandle) raises -> Int:
    var gpu_stream_synchronize_active_fn = lib.get_function[
        GpuStreamSynchronizeActiveFn
    ]("amrex_mojo_gpu_stream_synchronize_active")
    return Int(gpu_stream_synchronize_active_fn())


def parallel_nprocs(ref lib: OwnedDLHandle) raises -> Int:
    var parallel_nprocs_fn = lib.get_function[ParallelNprocsFn](
        "amrex_mojo_parallel_nprocs"
    )
    return Int(parallel_nprocs_fn())


def parallel_myproc(ref lib: OwnedDLHandle) raises -> Int:
    var parallel_myproc_fn = lib.get_function[ParallelMyprocFn](
        "amrex_mojo_parallel_myproc"
    )
    return Int(parallel_myproc_fn())


def parallel_ioprocessor(ref lib: OwnedDLHandle) raises -> Bool:
    var parallel_ioprocessor_fn = lib.get_function[ParallelIoprocessorFn](
        "amrex_mojo_parallel_ioprocessor"
    )
    return parallel_ioprocessor_fn() != 0


def parallel_ioprocessor_number(ref lib: OwnedDLHandle) raises -> Int:
    var parallel_ioprocessor_number_fn = lib.get_function[
        ParallelIoprocessorNumberFn
    ]("amrex_mojo_parallel_ioprocessor_number")
    return Int(parallel_ioprocessor_number_fn())


def boxarray_create_from_box(
    ref lib: OwnedDLHandle, runtime: RuntimeHandle, domain: Box3D
) raises -> BoxArrayHandle:
    var boxarray_create_from_bounds_fn = lib.get_function[
        BoxArrayCreateFromBoundsFn
    ]("amrex_mojo_boxarray_create_from_bounds")
    return boxarray_create_from_bounds_fn(
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
    var boxarray_destroy_fn = lib.get_function[BoxArrayDestroyFn](
        "amrex_mojo_boxarray_destroy"
    )
    boxarray_destroy_fn(boxarray)


def boxarray_max_size(
    ref lib: OwnedDLHandle, boxarray: BoxArrayHandle, max_size: IntVect3D
) raises -> Int:
    var boxarray_max_size_xyz_fn = lib.get_function[BoxArrayMaxSizeXyzFn](
        "amrex_mojo_boxarray_max_size_xyz"
    )
    return Int(boxarray_max_size_xyz_fn(boxarray, max_size.x, max_size.y, max_size.z))


def boxarray_size(
    ref lib: OwnedDLHandle, boxarray: BoxArrayHandle
) raises -> Int:
    var boxarray_size_fn = lib.get_function[BoxArraySizeFn](
        "amrex_mojo_boxarray_size"
    )
    return Int(boxarray_size_fn(boxarray))


def distmap_create_from_boxarray(
    ref lib: OwnedDLHandle,
    runtime: RuntimeHandle,
    boxarray: BoxArrayHandle,
) raises -> DistributionMappingHandle:
    var distmap_create_from_boxarray_fn = lib.get_function[
        DistmapCreateFromBoxarrayFn
    ]("amrex_mojo_distmap_create_from_boxarray")
    return distmap_create_from_boxarray_fn(runtime, boxarray)


def distmap_destroy(
    ref lib: OwnedDLHandle, distmap: DistributionMappingHandle
) raises:
    var distmap_destroy_fn = lib.get_function[DistmapDestroyFn](
        "amrex_mojo_distmap_destroy"
    )
    distmap_destroy_fn(distmap)


def geometry_create(
    ref lib: OwnedDLHandle, runtime: RuntimeHandle, domain: Box3D
) raises -> GeometryHandle:
    var geometry_create_from_bounds_fn = lib.get_function[
        GeometryCreateFromBoundsFn
    ]("amrex_mojo_geometry_create_from_bounds")
    return geometry_create_from_bounds_fn(
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


def geometry_create(
    ref lib: OwnedDLHandle,
    runtime: RuntimeHandle,
    domain: Box3D,
    real_box: RealBox3D,
    is_periodic: IntVect3D,
) raises -> GeometryHandle:
    var geometry_create_with_real_box_fn = lib.get_function[
        GeometryCreateFromBoundsWithRealBoxAndPeriodicityFn
    ]("amrex_mojo_geometry_create_from_bounds_with_real_box_and_periodicity")
    return geometry_create_with_real_box_fn(
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
        c_double(real_box.lo_x),
        c_double(real_box.lo_y),
        c_double(real_box.lo_z),
        c_double(real_box.hi_x),
        c_double(real_box.hi_y),
        c_double(real_box.hi_z),
        is_periodic.x,
        is_periodic.y,
        is_periodic.z,
    )


def geometry_destroy(ref lib: OwnedDLHandle, geometry: GeometryHandle) raises:
    var geometry_destroy_fn = lib.get_function[GeometryDestroyFn](
        "amrex_mojo_geometry_destroy"
    )
    geometry_destroy_fn(geometry)


def multifab_create(
    ref lib: OwnedDLHandle,
    runtime: RuntimeHandle,
    boxarray: BoxArrayHandle,
    distmap: DistributionMappingHandle,
    ncomp: Int,
    ngrow: IntVect3D,
    host_only: Bool = False,
    datatype: Int = MULTIFAB_DATATYPE_FLOAT64,
) raises -> MultiFabHandle:
    var multifab_create_fn = lib.get_function[
        MultifabCreateWithMemoryAndDatatypeXyzFn
    ]("amrex_mojo_multifab_create_with_memory_and_datatype_xyz")
    return multifab_create_fn(
        runtime,
        boxarray,
        distmap,
        c_int(ncomp),
        ngrow.x,
        ngrow.y,
        ngrow.z,
        c_int(1 if host_only else 0),
        c_int(datatype),
    )


def multifab_destroy(ref lib: OwnedDLHandle, multifab: MultiFabHandle) raises:
    var multifab_destroy_fn = lib.get_function[MultifabDestroyFn](
        "amrex_mojo_multifab_destroy"
    )
    multifab_destroy_fn(multifab)


def multifab_ncomp(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle
) raises -> Int:
    var multifab_ncomp_fn = lib.get_function[MultifabNcompFn](
        "amrex_mojo_multifab_ncomp"
    )
    return Int(multifab_ncomp_fn(multifab))


def multifab_datatype(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle
) raises -> Int:
    var multifab_datatype_fn = lib.get_function[MultifabDatatypeFn](
        "amrex_mojo_multifab_datatype"
    )
    return Int(multifab_datatype_fn(multifab))


def multifab_memory_info(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle
) raises -> MultiFabMemoryInfo:
    # Keep `.call[...]` here: typed indirect calls are stricter about output
    # buffer pointer origins than the direct symbol call helper.
    var raw = List[c_int](length=6, fill=0)
    _ = lib.call["amrex_mojo_multifab_memory_info", c_int](
        multifab, raw.unsafe_ptr()
    )
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
    var multifab_set_val_fn = lib.get_function[MultifabSetValFn](
        "amrex_mojo_multifab_set_val"
    )
    return Int(
        multifab_set_val_fn(multifab, c_double(value), c_int(start_comp), c_int(ncomp))
    )


def multifab_tile_count(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle
) raises -> Int:
    var multifab_tile_count_fn = lib.get_function[MultifabTileCountFn](
        "amrex_mojo_multifab_tile_count"
    )
    return Int(multifab_tile_count_fn(multifab))


def multifab_tile_box(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> Box3D:
    var multifab_tile_box_fn = lib.get_function[MultifabTileBoxFn](
        "amrex_mojo_multifab_tile_box"
    )
    return multifab_tile_box_fn(multifab, c_int(tile_index))


def multifab_valid_box(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> Box3D:
    var multifab_valid_box_fn = lib.get_function[MultifabValidBoxFn](
        "amrex_mojo_multifab_valid_box"
    )
    return multifab_valid_box_fn(multifab, c_int(tile_index))


def mfiter_create(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle
) raises -> MFIterHandle:
    # Keep `.call[...]` here: the out-parameter buffer is a local-origin
    # pointer that does not drop into the typed indirect-call path.
    var out_handle = List[MFIterHandle](length=1, fill=MFIterHandle())
    _ = lib.call["amrex_mojo_mfiter_create", c_int](
        multifab,
        out_handle.unsafe_ptr(),
    )
    return out_handle[0]


def mfiter_destroy(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises:
    var mfiter_destroy_fn = lib.get_function[MfiterDestroyFn](
        "amrex_mojo_mfiter_destroy"
    )
    mfiter_destroy_fn(mfiter)


def mfiter_is_valid(
    ref lib: OwnedDLHandle, mfiter: MFIterHandle
) raises -> Bool:
    var mfiter_is_valid_fn = lib.get_function[MfiterIsValidFn](
        "amrex_mojo_mfiter_is_valid"
    )
    return mfiter_is_valid_fn(mfiter) != 0


def mfiter_next(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises -> Int:
    var mfiter_next_fn = lib.get_function[MfiterNextFn]("amrex_mojo_mfiter_next")
    return Int(mfiter_next_fn(mfiter))


def mfiter_index(ref lib: OwnedDLHandle, mfiter: MFIterHandle) raises -> Int:
    var mfiter_index_fn = lib.get_function[MfiterIndexFn]("amrex_mojo_mfiter_index")
    return Int(mfiter_index_fn(mfiter))


def mfiter_local_tile_index(
    ref lib: OwnedDLHandle, mfiter: MFIterHandle
) raises -> Int:
    var mfiter_local_tile_index_fn = lib.get_function[MfiterLocalTileIndexFn](
        "amrex_mojo_mfiter_local_tile_index"
    )
    return Int(mfiter_local_tile_index_fn(mfiter))


def mfiter_tile_box(
    ref lib: OwnedDLHandle, mfiter: MFIterHandle
) raises -> Box3DResult:
    # Keep `.call[...]` here: metadata APIs write through local output buffers,
    # which currently fail typed indirect-call origin checks.
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
    # Keep `.call[...]` here: metadata APIs write through local output buffers,
    # which currently fail typed indirect-call origin checks.
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
    # Keep `.call[...]` here: metadata APIs write through local output buffers,
    # which currently fail typed indirect-call origin checks.
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
    # Keep `.call[...]` here: metadata APIs write through local output buffers,
    # which currently fail typed indirect-call origin checks.
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


def raw_array4_metadata(
    data_lo: List[c_int], data_hi: List[c_int], stride: List[Int64], ncomp_raw: List[c_int]
) -> RawArray4Metadata:
    return RawArray4Metadata(
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


def raw_tile_metadata(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> RawTileMetadata:
    var tile_lo = List[c_int](length=3, fill=0)
    var tile_hi = List[c_int](length=3, fill=0)
    var valid_lo = List[c_int](length=3, fill=0)
    var valid_hi = List[c_int](length=3, fill=0)
    var data_lo = List[c_int](length=3, fill=0)
    var data_hi = List[c_int](length=3, fill=0)
    var stride = List[Int64](length=4, fill=0)
    var ncomp_raw = List[c_int](length=1, fill=0)

    # Keep `.call[...]` here: this metadata API writes through local output
    # buffers, which currently fail typed indirect-call origin checks.
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

    return RawTileMetadata(
        tile_box=box_from_bounds(tile_lo, tile_hi),
        valid_box=box_from_bounds(valid_lo, valid_hi),
        array=raw_array4_metadata(data_lo, data_hi, stride, ncomp_raw),
    )


def raw_array4_metadata_for_mfiter(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> RawArray4Metadata:
    var data_lo = List[c_int](length=3, fill=0)
    var data_hi = List[c_int](length=3, fill=0)
    var stride = List[Int64](length=4, fill=0)
    var ncomp_raw = List[c_int](length=1, fill=0)

    # Keep `.call[...]` here: this metadata API writes through local output
    # buffers, which currently fail typed indirect-call origin checks.
    _ = lib.call["amrex_mojo_multifab_array4_metadata_for_mfiter", c_int](
        multifab,
        mfiter,
        data_lo.unsafe_ptr(),
        data_hi.unsafe_ptr(),
        stride.unsafe_ptr(),
        ncomp_raw.unsafe_ptr(),
    )

    return raw_array4_metadata(data_lo, data_hi, stride, ncomp_raw)


def raw_data_ptr_f64(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> UnsafePointer[c_double, MutAnyOrigin]:
    # Keep `.call[...]` here: this path returns a pointer for later origin
    # adaptation in higher layers.
    return lib.call[
        "amrex_mojo_multifab_data_ptr",
        UnsafePointer[c_double, MutAnyOrigin],
    ](multifab, c_int(tile_index))


def raw_data_ptr_f64_device(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> UnsafePointer[c_double, MutAnyOrigin]:
    # Keep `.call[...]` here: this path returns a device pointer for later
    # origin adaptation in higher layers.
    return lib.call[
        "amrex_mojo_multifab_data_ptr_device",
        UnsafePointer[c_double, MutAnyOrigin],
    ](multifab, c_int(tile_index))


def raw_data_ptr_f32(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> UnsafePointer[c_float, MutAnyOrigin]:
    # Keep `.call[...]` here: this path returns a pointer for later origin
    # adaptation in higher layers.
    return lib.call[
        "amrex_mojo_multifab_data_ptr_f32",
        UnsafePointer[c_float, MutAnyOrigin],
    ](multifab, c_int(tile_index))


def raw_data_ptr_f32_device(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> UnsafePointer[c_float, MutAnyOrigin]:
    # Keep `.call[...]` here: this path returns a device pointer for later
    # origin adaptation in higher layers.
    return lib.call[
        "amrex_mojo_multifab_data_ptr_device_f32",
        UnsafePointer[c_float, MutAnyOrigin],
    ](multifab, c_int(tile_index))


def raw_data_ptr_f64_for_mfiter(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> UnsafePointer[c_double, MutAnyOrigin]:
    # Keep `.call[...]` here: this path returns a pointer for later origin
    # adaptation in higher layers.
    return lib.call[
        "amrex_mojo_multifab_data_ptr_for_mfiter",
        UnsafePointer[c_double, MutAnyOrigin],
    ](multifab, mfiter)


def raw_data_ptr_f64_for_mfiter_device(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> UnsafePointer[c_double, MutAnyOrigin]:
    # Keep `.call[...]` here: this path returns a device pointer for later
    # origin adaptation in higher layers.
    return lib.call[
        "amrex_mojo_multifab_data_ptr_for_mfiter_device",
        UnsafePointer[c_double, MutAnyOrigin],
    ](multifab, mfiter)


def raw_data_ptr_f32_for_mfiter(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> UnsafePointer[c_float, MutAnyOrigin]:
    # Keep `.call[...]` here: this path returns a pointer for later origin
    # adaptation in higher layers.
    return lib.call[
        "amrex_mojo_multifab_data_ptr_for_mfiter_f32",
        UnsafePointer[c_float, MutAnyOrigin],
    ](multifab, mfiter)


def raw_data_ptr_f32_for_mfiter_device(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> UnsafePointer[c_float, MutAnyOrigin]:
    # Keep `.call[...]` here: this path returns a device pointer for later
    # origin adaptation in higher layers.
    return lib.call[
        "amrex_mojo_multifab_data_ptr_for_mfiter_device_f32",
        UnsafePointer[c_float, MutAnyOrigin],
    ](multifab, mfiter)


def tile_view[
    owner_origin: Origin[mut=True]
](
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> TileF64View[owner_origin]:
    # Keep `.call[...]` here: this path mixes output buffers with a generic
    # return-pointer origin, which does not map cleanly onto `get_function[...]`.
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
        ](multifab, c_int(tile_index)),
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


def device_tile_view(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> TileF64View[MutAnyOrigin]:
    # Keep `.call[...]` here: this path uses output buffers plus device pointer
    # returns, which currently hit typed indirect-call origin restrictions.
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

    var array_view = Array4F64View[MutAnyOrigin](
        data=lib.call[
            "amrex_mojo_multifab_data_ptr_device",
            UnsafePointer[c_double, MutAnyOrigin],
        ](multifab, c_int(tile_index)),
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

    return TileF64View[MutAnyOrigin](
        tile_box=box_from_bounds(tile_lo, tile_hi),
        valid_box=box_from_bounds(valid_lo, valid_hi),
        array_view=array_view.copy(),
    )


def tile_view_f32[
    owner_origin: Origin[mut=True]
](
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> TileF32View[owner_origin]:
    # Keep `.call[...]` here: this path mixes output buffers with a generic
    # return-pointer origin, which does not map cleanly onto `get_function[...]`.
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

    var array_view = Array4F32View[owner_origin](
        data=lib.call[
            "amrex_mojo_multifab_data_ptr_f32",
            UnsafePointer[c_float, owner_origin],
        ](multifab, c_int(tile_index)),
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

    return TileF32View[owner_origin](
        tile_box=box_from_bounds(tile_lo, tile_hi),
        valid_box=box_from_bounds(valid_lo, valid_hi),
        array_view=array_view.copy(),
    )


def device_tile_view_f32(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, tile_index: Int
) raises -> TileF32View[MutAnyOrigin]:
    # Keep `.call[...]` here: this path uses output buffers plus device pointer
    # returns, which currently hit typed indirect-call origin restrictions.
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

    var array_view = Array4F32View[MutAnyOrigin](
        data=lib.call[
            "amrex_mojo_multifab_data_ptr_device_f32",
            UnsafePointer[c_float, MutAnyOrigin],
        ](multifab, c_int(tile_index)),
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

    return TileF32View[MutAnyOrigin](
        tile_box=box_from_bounds(tile_lo, tile_hi),
        valid_box=box_from_bounds(valid_lo, valid_hi),
        array_view=array_view.copy(),
    )


def array4_view_from_mfiter[
    owner_origin: Origin[mut=True]
](
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> Array4F64View[owner_origin]:
    # Keep `.call[...]` here: generic-origin data pointers and output buffers
    # are not a drop-in fit for typed indirect calls.
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


def device_array4_view_from_mfiter(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> Array4F64View[MutAnyOrigin]:
    # Keep `.call[...]` here: device-pointer returns plus output buffers
    # currently require the more permissive direct symbol call path.
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

    return Array4F64View[MutAnyOrigin](
        data=lib.call[
            "amrex_mojo_multifab_data_ptr_for_mfiter_device",
            UnsafePointer[c_double, MutAnyOrigin],
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


def array4_view_from_mfiter_f32[
    owner_origin: Origin[mut=True]
](
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> Array4F32View[owner_origin]:
    # Keep `.call[...]` here: generic-origin data pointers and output buffers
    # are not a drop-in fit for typed indirect calls.
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

    return Array4F32View[owner_origin](
        data=lib.call[
            "amrex_mojo_multifab_data_ptr_for_mfiter_f32",
            UnsafePointer[c_float, owner_origin],
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


def device_array4_view_from_mfiter_f32(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    mfiter: MFIterHandle,
) raises -> Array4F32View[MutAnyOrigin]:
    # Keep `.call[...]` here: device-pointer returns plus output buffers
    # currently require the more permissive direct symbol call path.
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

    return Array4F32View[MutAnyOrigin](
        data=lib.call[
            "amrex_mojo_multifab_data_ptr_for_mfiter_device_f32",
            UnsafePointer[c_float, MutAnyOrigin],
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
    var multifab_sum_fn = lib.get_function[MultifabSumFn]("amrex_mojo_multifab_sum")
    return multifab_sum_fn(multifab, c_int(comp))


def boxarray_box(
    ref lib: OwnedDLHandle, boxarray: BoxArrayHandle, index: Int
) raises -> Box3DResult:
    # Keep `.call[...]` here: metadata APIs write through local output buffers,
    # which currently fail typed indirect-call origin checks.
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
    # Keep `.call[...]` here: metadata APIs write through local output buffers,
    # which currently fail typed indirect-call origin checks.
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
    # Keep `.call[...]` here: metadata APIs write through local output buffers,
    # which currently fail typed indirect-call origin checks.
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
    # Keep `.call[...]` here: metadata APIs write through local output buffers,
    # which currently fail typed indirect-call origin checks.
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
    # Keep `.call[...]` here: metadata APIs write through local output buffers,
    # which currently fail typed indirect-call origin checks.
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
    var multifab_min_fn = lib.get_function[MultifabMinFn]("amrex_mojo_multifab_min")
    return multifab_min_fn(multifab, c_int(comp))


def multifab_max(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    var multifab_max_fn = lib.get_function[MultifabMaxFn]("amrex_mojo_multifab_max")
    return multifab_max_fn(multifab, c_int(comp))


def multifab_norm0(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    var multifab_norm0_fn = lib.get_function[MultifabNorm0Fn](
        "amrex_mojo_multifab_norm0"
    )
    return multifab_norm0_fn(multifab, c_int(comp))


def multifab_norm1(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    var multifab_norm1_fn = lib.get_function[MultifabNorm1Fn](
        "amrex_mojo_multifab_norm1"
    )
    return multifab_norm1_fn(multifab, c_int(comp))


def multifab_norm2(
    ref lib: OwnedDLHandle, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    var multifab_norm2_fn = lib.get_function[MultifabNorm2Fn](
        "amrex_mojo_multifab_norm2"
    )
    return multifab_norm2_fn(multifab, c_int(comp))


def multifab_plus(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    var multifab_plus_fn = lib.get_function[MultifabPlusFn](
        "amrex_mojo_multifab_plus"
    )
    return Int(multifab_plus_fn(multifab, c_double(value), c_int(start_comp), c_int(ncomp), ngrow))


def multifab_mult(
    ref lib: OwnedDLHandle,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    var multifab_mult_fn = lib.get_function[MultifabMultFn](
        "amrex_mojo_multifab_mult"
    )
    return Int(multifab_mult_fn(multifab, c_double(value), c_int(start_comp), c_int(ncomp), ngrow))


def multifab_copy(
    ref lib: OwnedDLHandle,
    dst_multifab: MultiFabHandle,
    src_multifab: MultiFabHandle,
    src_comp: Int,
    dst_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    var multifab_copy_fn = lib.get_function[MultifabCopyFn](
        "amrex_mojo_multifab_copy"
    )
    return Int(
        multifab_copy_fn(
            dst_multifab,
            src_multifab,
            c_int(src_comp),
            c_int(dst_comp),
            c_int(ncomp),
            ngrow,
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
    var multifab_parallel_copy_fn = lib.get_function[MultifabParallelCopyFn](
        "amrex_mojo_multifab_parallel_copy"
    )
    return Int(
        multifab_parallel_copy_fn(
            dst_multifab,
            src_multifab,
            geometry,
            c_int(src_comp),
            c_int(dst_comp),
            c_int(ncomp),
            src_ngrow,
            dst_ngrow,
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
    var multifab_fill_boundary_fn = lib.get_function[MultifabFillBoundaryFn](
        "amrex_mojo_multifab_fill_boundary"
    )
    return Int(
        multifab_fill_boundary_fn(
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
    # Keep `.call[...]` here: the C string pointer carries a local origin that
    # is accepted here but not by the typed indirect-call path.
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
    # Keep `.call[...]` here: the C string pointer carries a local origin that
    # is accepted here but not by the typed indirect-call path.
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
    # Keep `.call[...]` here: the C string pointer carries a local origin that
    # is accepted here but not by the typed indirect-call path.
    var prefix_owned = prefix
    return lib.call["amrex_mojo_parmparse_create", ParmParseHandle](
        runtime, prefix_owned.as_c_string_slice().unsafe_ptr()
    )


def parmparse_create(
    ref lib: OwnedDLHandle, runtime: RuntimeHandle, prefix: StringLiteral
) raises -> ParmParseHandle:
    # Keep `.call[...]` here: the C string pointer carries a local origin that
    # is accepted here but not by the typed indirect-call path.
    return lib.call["amrex_mojo_parmparse_create", ParmParseHandle](
        runtime, prefix.as_c_string_slice().unsafe_ptr()
    )


def parmparse_destroy(
    ref lib: OwnedDLHandle, parmparse: ParmParseHandle
) raises:
    var parmparse_destroy_fn = lib.get_function[ParmparseDestroyFn](
        "amrex_mojo_parmparse_destroy"
    )
    parmparse_destroy_fn(parmparse)


def last_error_message(ref functions: AmrexFunctionCache) raises -> String:
    var message = functions.last_error_message_fn()
    if not message:
        return String("AMReX call failed.")
    return String(unsafe_from_utf8_ptr=message)


def abi_version(ref functions: AmrexFunctionCache) raises -> Int:
    return Int(functions.abi_version_fn())


def runtime_create(ref functions: AmrexFunctionCache) raises -> RuntimeHandle:
    return functions.runtime_create_default_fn()


def runtime_create(
    ref functions: AmrexFunctionCache, device_id: Int
) raises -> RuntimeHandle:
    return functions.runtime_create_default_on_device_fn(c_int(device_id))


def runtime_destroy(
    ref functions: AmrexFunctionCache, runtime: RuntimeHandle
) raises:
    functions.runtime_destroy_fn(runtime)


def runtime_initialized(
    ref functions: AmrexFunctionCache, runtime: RuntimeHandle
) raises -> Bool:
    return functions.runtime_initialized_fn(runtime) != 0


def gpu_backend(ref functions: AmrexFunctionCache) raises -> Int:
    return Int(functions.gpu_backend_fn())


def gpu_device_id(ref functions: AmrexFunctionCache) raises -> Int:
    return Int(functions.gpu_device_id_fn())


def gpu_num_streams(ref functions: AmrexFunctionCache) raises -> Int:
    return Int(functions.gpu_num_streams_fn())


def gpu_set_stream_index(
    ref functions: AmrexFunctionCache, stream_index: Int
) raises -> Int:
    return Int(functions.gpu_set_stream_index_fn(c_int(stream_index)))


def gpu_reset_stream(ref functions: AmrexFunctionCache) raises:
    functions.gpu_reset_stream_fn()


def gpu_stream(
    ref functions: AmrexFunctionCache,
) raises -> UnsafePointer[NoneType, MutExternalOrigin]:
    return functions.gpu_stream_fn()


def gpu_stream_synchronize_active(ref functions: AmrexFunctionCache) raises -> Int:
    return Int(functions.gpu_stream_synchronize_active_fn())


def parallel_nprocs(ref functions: AmrexFunctionCache) raises -> Int:
    return Int(functions.parallel_nprocs_fn())


def parallel_myproc(ref functions: AmrexFunctionCache) raises -> Int:
    return Int(functions.parallel_myproc_fn())


def parallel_ioprocessor(ref functions: AmrexFunctionCache) raises -> Bool:
    return functions.parallel_ioprocessor_fn() != 0


def parallel_ioprocessor_number(ref functions: AmrexFunctionCache) raises -> Int:
    return Int(functions.parallel_ioprocessor_number_fn())


def boxarray_create_from_box(
    ref functions: AmrexFunctionCache, runtime: RuntimeHandle, domain: Box3D
) raises -> BoxArrayHandle:
    return functions.boxarray_create_from_bounds_fn(
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


def boxarray_destroy(
    ref functions: AmrexFunctionCache, boxarray: BoxArrayHandle
) raises:
    functions.boxarray_destroy_fn(boxarray)


def boxarray_max_size(
    ref functions: AmrexFunctionCache, boxarray: BoxArrayHandle, max_size: IntVect3D
) raises -> Int:
    return Int(
        functions.boxarray_max_size_xyz_fn(
            boxarray, max_size.x, max_size.y, max_size.z
        )
    )


def boxarray_size(
    ref functions: AmrexFunctionCache, boxarray: BoxArrayHandle
) raises -> Int:
    return Int(functions.boxarray_size_fn(boxarray))


def distmap_create_from_boxarray(
    ref functions: AmrexFunctionCache,
    runtime: RuntimeHandle,
    boxarray: BoxArrayHandle,
) raises -> DistributionMappingHandle:
    return functions.distmap_create_from_boxarray_fn(runtime, boxarray)


def distmap_destroy(
    ref functions: AmrexFunctionCache, distmap: DistributionMappingHandle
) raises:
    functions.distmap_destroy_fn(distmap)


def geometry_create(
    ref functions: AmrexFunctionCache, runtime: RuntimeHandle, domain: Box3D
) raises -> GeometryHandle:
    return functions.geometry_create_from_bounds_fn(
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


def geometry_create(
    ref functions: AmrexFunctionCache,
    runtime: RuntimeHandle,
    domain: Box3D,
    real_box: RealBox3D,
    is_periodic: IntVect3D,
) raises -> GeometryHandle:
    return functions.geometry_create_with_real_box_fn(
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
        c_double(real_box.lo_x),
        c_double(real_box.lo_y),
        c_double(real_box.lo_z),
        c_double(real_box.hi_x),
        c_double(real_box.hi_y),
        c_double(real_box.hi_z),
        is_periodic.x,
        is_periodic.y,
        is_periodic.z,
    )


def geometry_destroy(
    ref functions: AmrexFunctionCache, geometry: GeometryHandle
) raises:
    functions.geometry_destroy_fn(geometry)


def multifab_create(
    ref functions: AmrexFunctionCache,
    runtime: RuntimeHandle,
    boxarray: BoxArrayHandle,
    distmap: DistributionMappingHandle,
    ncomp: Int,
    ngrow: IntVect3D,
    host_only: Bool = False,
    datatype: Int = MULTIFAB_DATATYPE_FLOAT64,
) raises -> MultiFabHandle:
    return functions.multifab_create_fn(
        runtime,
        boxarray,
        distmap,
        c_int(ncomp),
        ngrow.x,
        ngrow.y,
        ngrow.z,
        c_int(1 if host_only else 0),
        c_int(datatype),
    )


def multifab_destroy(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle
) raises:
    functions.multifab_destroy_fn(multifab)


def multifab_ncomp(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle
) raises -> Int:
    return Int(functions.multifab_ncomp_fn(multifab))


def multifab_datatype(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle
) raises -> Int:
    return Int(functions.multifab_datatype_fn(multifab))


def multifab_set_val(
    ref functions: AmrexFunctionCache,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
) raises -> Int:
    return Int(
        functions.multifab_set_val_fn(
            multifab, c_double(value), c_int(start_comp), c_int(ncomp)
        )
    )


def multifab_tile_count(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle
) raises -> Int:
    return Int(functions.multifab_tile_count_fn(multifab))


def multifab_tile_box(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle, tile_index: Int
) raises -> Box3D:
    return functions.multifab_tile_box_fn(multifab, c_int(tile_index))


def multifab_valid_box(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle, tile_index: Int
) raises -> Box3D:
    return functions.multifab_valid_box_fn(multifab, c_int(tile_index))


def mfiter_destroy(
    ref functions: AmrexFunctionCache, mfiter: MFIterHandle
) raises:
    functions.mfiter_destroy_fn(mfiter)


def mfiter_is_valid(
    ref functions: AmrexFunctionCache, mfiter: MFIterHandle
) raises -> Bool:
    return functions.mfiter_is_valid_fn(mfiter) != 0


def mfiter_next(ref functions: AmrexFunctionCache, mfiter: MFIterHandle) raises -> Int:
    return Int(functions.mfiter_next_fn(mfiter))


def mfiter_index(
    ref functions: AmrexFunctionCache, mfiter: MFIterHandle
) raises -> Int:
    return Int(functions.mfiter_index_fn(mfiter))


def mfiter_local_tile_index(
    ref functions: AmrexFunctionCache, mfiter: MFIterHandle
) raises -> Int:
    return Int(functions.mfiter_local_tile_index_fn(mfiter))


def multifab_sum(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return functions.multifab_sum_fn(multifab, c_int(comp))


def multifab_min(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return functions.multifab_min_fn(multifab, c_int(comp))


def multifab_max(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return functions.multifab_max_fn(multifab, c_int(comp))


def multifab_norm0(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return functions.multifab_norm0_fn(multifab, c_int(comp))


def multifab_norm1(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return functions.multifab_norm1_fn(multifab, c_int(comp))


def multifab_norm2(
    ref functions: AmrexFunctionCache, multifab: MultiFabHandle, comp: Int
) raises -> Float64:
    return functions.multifab_norm2_fn(multifab, c_int(comp))


def multifab_plus(
    ref functions: AmrexFunctionCache,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    return Int(
        functions.multifab_plus_fn(
            multifab, c_double(value), c_int(start_comp), c_int(ncomp), ngrow
        )
    )


def multifab_mult(
    ref functions: AmrexFunctionCache,
    multifab: MultiFabHandle,
    value: Float64,
    start_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    return Int(
        functions.multifab_mult_fn(
            multifab, c_double(value), c_int(start_comp), c_int(ncomp), ngrow
        )
    )


def multifab_copy(
    ref functions: AmrexFunctionCache,
    dst_multifab: MultiFabHandle,
    src_multifab: MultiFabHandle,
    src_comp: Int,
    dst_comp: Int,
    ncomp: Int,
    ngrow: IntVect3D,
) raises -> Int:
    return Int(
        functions.multifab_copy_fn(
            dst_multifab,
            src_multifab,
            c_int(src_comp),
            c_int(dst_comp),
            c_int(ncomp),
            ngrow,
        )
    )


def multifab_parallel_copy(
    ref functions: AmrexFunctionCache,
    dst_multifab: MultiFabHandle,
    src_multifab: MultiFabHandle,
    geometry: GeometryHandle,
    src_comp: Int,
    dst_comp: Int,
    ncomp: Int,
    src_ngrow: IntVect3D,
    dst_ngrow: IntVect3D,
) raises -> Int:
    return Int(
        functions.multifab_parallel_copy_fn(
            dst_multifab,
            src_multifab,
            geometry,
            c_int(src_comp),
            c_int(dst_comp),
            c_int(ncomp),
            src_ngrow,
            dst_ngrow,
        )
    )


def multifab_fill_boundary(
    ref functions: AmrexFunctionCache,
    multifab: MultiFabHandle,
    geometry: GeometryHandle,
    start_comp: Int,
    ncomp: Int,
    cross: Bool = False,
) raises -> Int:
    return Int(
        functions.multifab_fill_boundary_fn(
            multifab,
            geometry,
            c_int(start_comp),
            c_int(ncomp),
            c_int(1 if cross else 0),
        )
    )


def parmparse_destroy(
    ref functions: AmrexFunctionCache, parmparse: ParmParseHandle
) raises:
    functions.parmparse_destroy_fn(parmparse)


def parmparse_add_int(
    ref lib: OwnedDLHandle,
    parmparse: ParmParseHandle,
    name: String,
    value: Int,
) raises -> Int:
    # Keep `.call[...]` here: the C string pointer carries a local origin that
    # is accepted here but not by the typed indirect-call path.
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
    # Keep `.call[...]` here: the C string pointer carries a local origin that
    # is accepted here but not by the typed indirect-call path.
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
    # Keep `.call[...]` here: this path combines a local-origin C string with
    # local output buffers, which the typed indirect-call path rejects.
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
    # Keep `.call[...]` here: this path combines a local-origin C string with
    # local output buffers, which the typed indirect-call path rejects.
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


def parmparse_query_real(
    ref lib: OwnedDLHandle, parmparse: ParmParseHandle, name: String
) raises -> ParmParseRealQueryResult:
    # Keep `.call[...]` here: this path combines a local-origin C string with
    # local output buffers, which the typed indirect-call path rejects.
    var name_owned = name
    var out_value = List[c_double](length=1, fill=0.0)
    var out_found = List[c_int](length=1, fill=0)
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


def parmparse_query_real(
    ref lib: OwnedDLHandle, parmparse: ParmParseHandle, name: StringLiteral
) raises -> ParmParseRealQueryResult:
    # Keep `.call[...]` here: this path combines a local-origin C string with
    # local output buffers, which the typed indirect-call path rejects.
    var out_value = List[c_double](length=1, fill=0.0)
    var out_found = List[c_int](length=1, fill=0)
    var status = Int(
        lib.call["amrex_mojo_parmparse_query_real", c_int](
            parmparse,
            name.as_c_string_slice().unsafe_ptr(),
            out_value.unsafe_ptr(),
            out_found.unsafe_ptr(),
        )
    )
    return ParmParseRealQueryResult(
        status=status,
        found=out_found[0] != 0,
        value=Float64(out_value[0]),
    )
