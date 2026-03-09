from std.ffi import OwnedDLHandle


fn load_library(path: String) raises -> OwnedDLHandle:
    return OwnedDLHandle(path)


fn load_default_library() raises -> OwnedDLHandle:
    return load_library(String("./build/src/capi/libamrex_mojo_capi_3d.dylib"))
