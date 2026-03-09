from std.ffi import OwnedDLHandle


fn default_library_path() -> String:
    return String("./build/src/capi/libamrex_mojo_capi_3d.dylib")


fn load_library(ref path: String) raises -> OwnedDLHandle:
    return OwnedDLHandle(path)


fn load_default_library() raises -> OwnedDLHandle:
    var path = default_library_path()
    return load_library(path)
