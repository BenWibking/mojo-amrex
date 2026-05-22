"""Compile-time mapping between Mojo floating `DType`s and AMReX C ABI symbols."""

from std.ffi import OwnedDLHandle, c_double, c_float


comptime MULTIFAB_DATATYPE_FLOAT64 = 0
comptime MULTIFAB_DATATYPE_FLOAT32 = 1


trait AmrexFloatingDtype:
    """Associates a supported scalar `DType` with AMReX multifab metadata."""

    comptime dtype: DType
    comptime c_type: AnyType
    comptime multifab_datatype_id: Int
    comptime array4_view_type_name: String
    comptime tile_view_type_name: String

    @staticmethod
    def mfiter_host_data_ptr[
        origin: Origin[mut=True]
    ](
        ref lib: OwnedDLHandle,
        multifab: UnsafePointer[NoneType, MutExternalOrigin],
        mfiter: UnsafePointer[NoneType, MutExternalOrigin],
    ) raises -> Optional[UnsafePointer[Self.c_type, origin]]:
        ...

    @staticmethod
    def mfiter_device_data_ptr[
        origin: Origin[mut=True]
    ](
        ref lib: OwnedDLHandle,
        multifab: UnsafePointer[NoneType, MutExternalOrigin],
        mfiter: UnsafePointer[NoneType, MutExternalOrigin],
    ) raises -> Optional[UnsafePointer[Self.c_type, origin]]:
        ...


struct AmrexFloat32(AmrexFloatingDtype):
    comptime dtype = DType.float32
    comptime c_type = c_float
    comptime multifab_datatype_id = MULTIFAB_DATATYPE_FLOAT32
    comptime array4_view_type_name = "Array4View[AmrexFloat32]"
    comptime tile_view_type_name = "TileView[AmrexFloat32]"

    @staticmethod
    def mfiter_host_data_ptr[
        origin: Origin[mut=True]
    ](
        ref lib: OwnedDLHandle,
        multifab: UnsafePointer[NoneType, MutExternalOrigin],
        mfiter: UnsafePointer[NoneType, MutExternalOrigin],
    ) raises -> Optional[UnsafePointer[Self.c_type, origin]]:
        return lib.call[
            "amrex_mojo_multifab_data_ptr_for_mfiter_f32",
            Optional[UnsafePointer[Self.c_type, origin]],
        ](multifab, mfiter)

    @staticmethod
    def mfiter_device_data_ptr[
        origin: Origin[mut=True]
    ](
        ref lib: OwnedDLHandle,
        multifab: UnsafePointer[NoneType, MutExternalOrigin],
        mfiter: UnsafePointer[NoneType, MutExternalOrigin],
    ) raises -> Optional[UnsafePointer[Self.c_type, origin]]:
        return lib.call[
            "amrex_mojo_multifab_data_ptr_for_mfiter_device_f32",
            Optional[UnsafePointer[Self.c_type, origin]],
        ](multifab, mfiter)


struct AmrexFloat64(AmrexFloatingDtype):
    comptime dtype = DType.float64
    comptime c_type = c_double
    comptime multifab_datatype_id = MULTIFAB_DATATYPE_FLOAT64
    comptime array4_view_type_name = "Array4View[AmrexFloat64]"
    comptime tile_view_type_name = "TileView[AmrexFloat64]"

    @staticmethod
    def mfiter_host_data_ptr[
        origin: Origin[mut=True]
    ](
        ref lib: OwnedDLHandle,
        multifab: UnsafePointer[NoneType, MutExternalOrigin],
        mfiter: UnsafePointer[NoneType, MutExternalOrigin],
    ) raises -> Optional[UnsafePointer[Self.c_type, origin]]:
        return lib.call[
            "amrex_mojo_multifab_data_ptr_for_mfiter",
            Optional[UnsafePointer[Self.c_type, origin]],
        ](multifab, mfiter)

    @staticmethod
    def mfiter_device_data_ptr[
        origin: Origin[mut=True]
    ](
        ref lib: OwnedDLHandle,
        multifab: UnsafePointer[NoneType, MutExternalOrigin],
        mfiter: UnsafePointer[NoneType, MutExternalOrigin],
    ) raises -> Optional[UnsafePointer[Self.c_type, origin]]:
        return lib.call[
            "amrex_mojo_multifab_data_ptr_for_mfiter_device",
            Optional[UnsafePointer[Self.c_type, origin]],
        ](multifab, mfiter)
