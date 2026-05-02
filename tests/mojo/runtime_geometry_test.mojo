from amrex.space3d import (
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    ParmParse,
    box3d,
    intvect3d,
    realbox3d,
    zero_intvect3d,
)
from std.collections import List


comptime DOMAIN_EXTENT = 64


def expect(condition: Bool, message: StringLiteral) raises:
    if not condition:
        raise Error(message)


def main() raises:
    var argv = List[String](length=3, fill=String(""))
    argv[0] = String("runtime_geometry_test")
    argv[1] = String("runtime_geometry_test.answer=17")
    argv[2] = String("runtime_geometry_test.dt=0.125")
    var runtime = AmrexRuntime(argv, use_parmparse=True)
    try:
        expect(runtime.abi_version() == 6, "unexpected ABI version")
        expect(runtime.initialized(), "runtime should be initialized")
        expect(runtime.nprocs() >= 1, "nprocs should be >= 1")
        expect(runtime.myproc() >= 0, "myproc should be >= 0")
        expect(
            runtime.gpu_num_streams() >= 1,
            "gpu_num_streams should be >= 1",
        )
        runtime.gpu_set_stream_index(0)
        runtime.gpu_synchronize_active_streams()
        runtime.gpu_reset_stream()
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
            try:
                expect(
                    same_device_runtime.gpu_device_id() == gpu_device_id,
                    "runtime created on explicit GPU device should match",
                )
                same_device_runtime^.close()
            except e:
                same_device_runtime^.close()
                raise e^

        var params = ParmParse(runtime, "runtime_geometry_test")
        expect(params.get_int("answer") == 17, "ParmParse get_int mismatch")
        expect(params.get_real("dt") == 0.125, "ParmParse get_real mismatch")
        expect(
            params.query_real_or("missing_dt", 0.5) == 0.5,
            "ParmParse query_real_or mismatch",
        )

        var zero = zero_intvect3d()
        expect(
            Int(zero.x) == 0 and Int(zero.y) == 0 and Int(zero.z) == 0,
            "zero_intvect3d mismatch",
        )

        var domain = box3d(
            small_end=intvect3d(0, 0, 0),
            big_end=intvect3d(DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1),
        )

        var boxarray = BoxArray(runtime, domain)
        boxarray.max_size(32)
        expect(boxarray.size() == 8, "boxarray should split into 8 boxes")

        var distmap = DistributionMapping(runtime, boxarray)
        _ = distmap

        var geometry = Geometry(runtime, domain)
        var periodicity = geometry.periodicity()
        expect(
            Int(periodicity.x) == 0 and Int(periodicity.y) == 0 and Int(periodicity.z) == 0,
            "geometry periodicity mismatch",
        )

        var periodic_geometry = Geometry(
            runtime,
            domain,
            realbox3d(0.0, 0.0, 0.0, 1.0, 2.0, 3.0),
            intvect3d(1, 0, 1),
        )
        periodicity = periodic_geometry.periodicity()
        expect(
            Int(periodicity.x) == 1 and Int(periodicity.y) == 0 and Int(periodicity.z) == 1,
            "custom geometry periodicity mismatch",
        )
        var prob_domain = periodic_geometry.prob_domain()
        expect(
            prob_domain.lo_x == 0.0
            and prob_domain.lo_y == 0.0
            and prob_domain.lo_z == 0.0
            and prob_domain.hi_x == 1.0
            and prob_domain.hi_y == 2.0
            and prob_domain.hi_z == 3.0,
            "custom geometry prob_domain mismatch",
        )
        var cell_size = periodic_geometry.cell_size()
        expect(
            cell_size.x == 1.0 / Float64(DOMAIN_EXTENT)
            and cell_size.y == 2.0 / Float64(DOMAIN_EXTENT)
            and cell_size.z == 3.0 / Float64(DOMAIN_EXTENT),
            "custom geometry cell_size mismatch",
        )

        print("runtime_geometry_test: ok")
        runtime^.close()
    except e:
        runtime^.close()
        raise e^
