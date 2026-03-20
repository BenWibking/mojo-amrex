from std.ffi import OwnedDLHandle
from std.os import getenv
from std.os.path import exists


def resolve_library_candidate(ref prefix: String) raises -> String:
    var so_candidate = prefix + ".so"
    if exists(so_candidate):
        return so_candidate

    var dylib_candidate = prefix + ".dylib"
    if exists(dylib_candidate):
        return dylib_candidate

    return String("")


def installed_library_path() raises -> String:
    var override_path = getenv("AMREX_MOJO_LIBRARY_PATH")
    if override_path:
        return override_path

    var conda_prefix = getenv("CONDA_PREFIX")
    if conda_prefix:
        var candidate = resolve_library_candidate(
            conda_prefix + "/lib/libamrex_mojo_capi_3d"
        )
        if exists(candidate):
            return candidate

    var modular_home = getenv("MODULAR_HOME")
    if modular_home:
        var candidate = resolve_library_candidate(
            modular_home + "/../../lib/libamrex_mojo_capi_3d"
        )
        if exists(candidate):
            return candidate

    return String("")


def default_library_path() raises -> String:
    var installed_path = installed_library_path()
    if installed_path:
        return installed_path

    var build_path = resolve_library_candidate(
        "./build/src/capi/libamrex_mojo_capi_3d"
    )
    if build_path:
        return build_path

    return String("./build/src/capi/libamrex_mojo_capi_3d.so")


def load_library(ref path: String) raises -> OwnedDLHandle:
    if not path:
        raise Error(
            "Unable to determine the AMReX Mojo C API library path. Set "
            + "AMREX_MOJO_LIBRARY_PATH or run `pixi run build-capi`."
        )
    if not exists(path):
        raise Error(
            "AMReX Mojo C API library not found at '"
            + path
            + "'. Run "
            + "`pixi run build-capi`, `pixi run install-amrex`, or set "
            + "AMREX_MOJO_LIBRARY_PATH."
        )
    return OwnedDLHandle(path)


def load_default_library() raises -> OwnedDLHandle:
    var path = default_library_path()
    return load_library(path)
