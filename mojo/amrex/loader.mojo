from std.ffi import OwnedDLHandle
from std.os import getenv
from std.os.path import exists


fn installed_library_path() -> String:
    var override_path = getenv("AMREX_MOJO_LIBRARY_PATH")
    if override_path:
        return override_path

    var conda_prefix = getenv("CONDA_PREFIX")
    if conda_prefix:
        var candidate = conda_prefix + "/lib/libamrex_mojo_capi_3d.dylib"
        if exists(candidate):
            return candidate

    var modular_home = getenv("MODULAR_HOME")
    if modular_home:
        var candidate = modular_home + "/../../lib/libamrex_mojo_capi_3d.dylib"
        if exists(candidate):
            return candidate

    return String("")


fn default_library_path() -> String:
    var installed_path = installed_library_path()
    if installed_path:
        return installed_path
    return String("./build/src/capi/libamrex_mojo_capi_3d.dylib")


fn load_library(ref path: String) raises -> OwnedDLHandle:
    return OwnedDLHandle(path)


fn load_default_library() raises -> OwnedDLHandle:
    var path = default_library_path()
    return load_library(path)
