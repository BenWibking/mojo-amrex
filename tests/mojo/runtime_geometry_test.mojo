# ABOUTME: Tests for runtime initialization, geometry, and ParmParse.
# ABOUTME: Exercises ABI version queries, GPU setup, and domain metadata.

from amrex.space3d import (
    AmrexRuntime,
    BoxArray,
    DistributionMapping,
    Geometry,
    ParmInt,
    ParmParse,
    ParmReal,
    box3d,
    intvect3d,
    realbox3d,
    zero_intvect3d,
)
from std.collections import List
from std.testing import assert_true


comptime DOMAIN_EXTENT = 64


def main() raises:
    var argv = List[String](length=3, fill=String(""))
    argv[0] = String("runtime_geometry_test")
    argv[1] = String("runtime_geometry_test.answer=17")
    argv[2] = String("runtime_geometry_test.dt=0.125")
    argv.append(String("top_level_answer=23"))
    var runtime = AmrexRuntime(argv, use_parmparse=True)
    try:
        assert_true(runtime.abi_version() == 6, "unexpected ABI version")
        assert_true(runtime.initialized(), "runtime should be initialized")
        assert_true(runtime.nprocs() >= 1, "nprocs should be >= 1")
        assert_true(runtime.myproc() >= 0, "myproc should be >= 0")
        assert_true(
            runtime.gpu_num_streams() >= 1,
            "gpu_num_streams should be >= 1",
        )
        runtime.gpu_set_stream_index(0)
        runtime.gpu_synchronize_active_streams()
        runtime.gpu_reset_stream()
        assert_true(
            runtime.ioprocessor_number() >= 0,
            "ioprocessor_number should be >= 0",
        )
        if runtime.gpu_backend() == "none":
            assert_true(
                runtime.gpu_device_id() == -1,
                "gpu_device_id should be -1 when AMReX has no GPU backend",
            )
        else:
            var gpu_device_id = runtime.gpu_device_id()
            assert_true(gpu_device_id >= 0, "gpu_device_id should be >= 0")
            var same_device_runtime = AmrexRuntime(gpu_device_id)
            try:
                assert_true(
                    same_device_runtime.gpu_device_id() == gpu_device_id,
                    "runtime created on explicit GPU device should match",
                )
                same_device_runtime^.close()
            except e:
                same_device_runtime^.close()
                raise e^

        var top_level_params = ParmParse(runtime)
        assert_true(
            top_level_params.get[ParmInt]("top_level_answer") == 23,
            "top-level ParmParse get_int mismatch",
        )

        var params = ParmParse(runtime, "runtime_geometry_test")
        assert_true(params.get[ParmInt]("answer") == 17, "ParmParse get_int mismatch")
        assert_true(params.get[ParmReal]("dt") == 0.125, "ParmParse get_real mismatch")
        assert_true(
            params.query_or[ParmReal]("missing_dt", 0.5) == 0.5,
            "ParmParse query_real_or mismatch",
        )

        var zero = zero_intvect3d()
        assert_true(
            Int(zero.x) == 0 and Int(zero.y) == 0 and Int(zero.z) == 0,
            "zero_intvect3d mismatch",
        )

        var domain = box3d(
            small_end=intvect3d(0, 0, 0),
            big_end=intvect3d(DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1),
        )

        var boxarray = BoxArray(runtime, domain)
        boxarray.max_size(32)
        assert_true(boxarray.size() == 8, "boxarray should split into 8 boxes")

        var distmap = DistributionMapping(runtime, boxarray)
        _ = distmap

        var geometry = Geometry(runtime, domain)
        var periodicity = geometry.periodicity()
        assert_true(
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
        assert_true(
            Int(periodicity.x) == 1 and Int(periodicity.y) == 0 and Int(periodicity.z) == 1,
            "custom geometry periodicity mismatch",
        )
        var prob_domain = periodic_geometry.prob_domain()
        assert_true(
            prob_domain.lo_x == 0.0
            and prob_domain.lo_y == 0.0
            and prob_domain.lo_z == 0.0
            and prob_domain.hi_x == 1.0
            and prob_domain.hi_y == 2.0
            and prob_domain.hi_z == 3.0,
            "custom geometry prob_domain mismatch",
        )
        var cell_size = periodic_geometry.cell_size()
        assert_true(
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
