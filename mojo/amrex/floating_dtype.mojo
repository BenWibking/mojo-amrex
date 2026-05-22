"""Compile-time mapping between Mojo floating `DType`s and AMReX C ABI symbols."""


comptime MULTIFAB_DATATYPE_FLOAT64 = 0
comptime MULTIFAB_DATATYPE_FLOAT32 = 1


trait AmrexFloatingDtype:
    """Associates a supported scalar `DType` with AMReX multifab metadata."""

    comptime dtype: DType
    comptime multifab_datatype_id: Int
    comptime array4_view_type_name: String
    comptime tile_view_type_name: String


struct AmrexFloat32(AmrexFloatingDtype):
    comptime dtype = DType.float32
    comptime multifab_datatype_id = MULTIFAB_DATATYPE_FLOAT32
    comptime array4_view_type_name = "Array4View[DType.float32]"
    comptime tile_view_type_name = "TileView[DType.float32]"
    comptime mfiter_host_ptr_symbol = "amrex_mojo_multifab_data_ptr_for_mfiter_f32"
    comptime mfiter_device_ptr_symbol = "amrex_mojo_multifab_data_ptr_for_mfiter_device_f32"


struct AmrexFloat64(AmrexFloatingDtype):
    comptime dtype = DType.float64
    comptime multifab_datatype_id = MULTIFAB_DATATYPE_FLOAT64
    comptime array4_view_type_name = "Array4View[DType.float64]"
    comptime tile_view_type_name = "TileView[DType.float64]"
    comptime mfiter_host_ptr_symbol = "amrex_mojo_multifab_data_ptr_for_mfiter"
    comptime mfiter_device_ptr_symbol = "amrex_mojo_multifab_data_ptr_for_mfiter_device"


def multifab_datatype_id_for[dtype: DType]() -> Int:
    comptime if dtype == DType.float32:
        return AmrexFloat32.multifab_datatype_id
    elif dtype == DType.float64:
        return AmrexFloat64.multifab_datatype_id
    else:
        comptime assert False, "AMReX only supports DType.float32 and DType.float64"


def array4_view_type_name_for[dtype: DType]() -> String:
    comptime if dtype == DType.float32:
        return AmrexFloat32.array4_view_type_name
    elif dtype == DType.float64:
        return AmrexFloat64.array4_view_type_name
    else:
        comptime assert False, "AMReX only supports DType.float32 and DType.float64"


def tile_view_type_name_for[dtype: DType]() -> String:
    comptime if dtype == DType.float32:
        return AmrexFloat32.tile_view_type_name
    elif dtype == DType.float64:
        return AmrexFloat64.tile_view_type_name
    else:
        comptime assert False, "AMReX only supports DType.float32 and DType.float64"
