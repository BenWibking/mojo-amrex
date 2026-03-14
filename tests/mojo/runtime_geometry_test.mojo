from amrex.space3d import (
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    ParmParse,
    box3d,
    intvect3d,
    zero_intvect3d,
)
from std.collections import List


comptime DOMAIN_EXTENT = 64


def expect(condition: Bool, message: StringLiteral) raises:
    if not condition:
        raise Error(message)


def main() raises:
    var argv = List[String](length=2, fill=String(""))
    argv[0] = String("runtime_geometry_test")
    argv[1] = String("runtime_geometry_test.answer=17")
    var runtime = AmrexRuntime(argv, use_parmparse=True)
    expect(runtime.abi_version() == 4, "unexpected ABI version")
    expect(runtime.initialized(), "runtime should be initialized")
    expect(runtime.nprocs() >= 1, "nprocs should be >= 1")
    expect(runtime.myproc() >= 0, "myproc should be >= 0")
    expect(
        runtime.ioprocessor_number() >= 0,
        "ioprocessor_number should be >= 0",
    )
    if runtime.gpu_backend() == "none":
        expect(
            runtime.gpu_device_id() == -1,
            "gpu_device_id should be -1 when AMReX has no GPU backend",
        )
    else:
        var gpu_device_id = runtime.gpu_device_id()
        expect(gpu_device_id >= 0, "gpu_device_id should be >= 0")
        var same_device_runtime = AmrexRuntime(gpu_device_id)
        expect(
            same_device_runtime.gpu_device_id() == gpu_device_id,
            "runtime created on explicit GPU device should match",
        )

    var params = ParmParse(runtime, "runtime_geometry_test")
    expect(params.query_int("answer") == 17, "ParmParse query_int mismatch")

    var zero = zero_intvect3d()
    expect(
        Int(zero.x) == 0 and Int(zero.y) == 0 and Int(zero.z) == 0,
        "zero_intvect3d mismatch",
    )

    var domain = box3d(
        small_end=intvect3d(0, 0, 0),
        big_end=intvect3d(
            DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1
        ),
    )

    var boxarray = BoxArray(runtime, domain)
    boxarray.max_size(32)
    expect(boxarray.size() == 8, "boxarray should split into 8 boxes")

    var distmap = DistributionMapping(runtime, boxarray)
    _ = distmap

    var geometry = Geometry(runtime, domain)
    var periodicity = geometry.periodicity()
    expect(
        Int(periodicity.x) == 0
        and Int(periodicity.y) == 0
        and Int(periodicity.z) == 0,
        "geometry periodicity mismatch",
    )

    print("runtime_geometry_test: ok")
