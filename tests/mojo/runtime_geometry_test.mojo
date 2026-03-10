from amrex.space3d import (
    AmrexRuntime,
    Box3D,
    BoxArray,
    DistributionMapping,
    Geometry,
    IntVect3D,
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


def abs_diff(lhs: Float64, rhs: Float64) raises -> Float64:
    if lhs >= rhs:
        return lhs - rhs
    return rhs - lhs


def expect_close(
    actual: Float64,
    expected: Float64,
    tolerance: Float64,
    message: StringLiteral,
) raises:
    expect(abs_diff(actual, expected) <= tolerance, message)


def expect_intvect(
    value: IntVect3D, x: Int, y: Int, z: Int, message: StringLiteral
) raises:
    expect(
        Int(value.x) == x and Int(value.y) == y and Int(value.z) == z,
        message,
    )


def expect_box(
    value: Box3D,
    lo_x: Int,
    lo_y: Int,
    lo_z: Int,
    hi_x: Int,
    hi_y: Int,
    hi_z: Int,
    message: StringLiteral,
) raises:
    expect(
        Int(value.small_end.x) == lo_x
        and Int(value.small_end.y) == lo_y
        and Int(value.small_end.z) == lo_z
        and Int(value.big_end.x) == hi_x
        and Int(value.big_end.y) == hi_y
        and Int(value.big_end.z) == hi_z,
        message,
    )


def box_cells(box: Box3D) raises -> Int:
    var nx = Int(box.big_end.x) - Int(box.small_end.x) + 1
    var ny = Int(box.big_end.y) - Int(box.small_end.y) + 1
    var nz = Int(box.big_end.z) - Int(box.small_end.z) + 1
    return nx * ny * nz


def main() raises:
    var argv = List[String](length=2, fill=String(""))
    argv[0] = String("runtime_geometry_test")
    argv[1] = String("runtime_geometry_test.answer=17")
    var runtime = AmrexRuntime(argv, use_parmparse=True)
    expect(runtime.abi_version() == 1, "unexpected ABI version")
    expect(runtime.initialized(), "runtime should be initialized")
    expect(runtime.nprocs() >= 1, "nprocs should be >= 1")
    expect(runtime.myproc() >= 0, "myproc should be >= 0")
    expect(
        runtime.ioprocessor_number() >= 0,
        "ioprocessor_number should be >= 0",
    )

    var params = ParmParse(runtime, "runtime_geometry_test")
    expect(params.query_int("answer") == 17, "ParmParse query_int mismatch")

    var zero = zero_intvect3d()
    expect_intvect(zero, 0, 0, 0, "zero_intvect3d mismatch")

    var domain = box3d(
        small_end=intvect3d(0, 0, 0),
        big_end=intvect3d(
            DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1, DOMAIN_EXTENT - 1
        ),
    )
    expect_box(
        domain,
        0,
        0,
        0,
        DOMAIN_EXTENT - 1,
        DOMAIN_EXTENT - 1,
        DOMAIN_EXTENT - 1,
        "domain mismatch",
    )

    var boxarray = BoxArray(runtime, domain)
    boxarray.max_size(32)
    expect(boxarray.size() == 8, "boxarray should split into 8 boxes")

    var total_cells = 0
    for i in range(boxarray.size()):
        var box = boxarray.box(i)
        expect_intvect(
            box.nodal, 0, 0, 0, "boxarray box should be cell centered"
        )
        expect(
            Int(box.small_end.x) >= 0
            and Int(box.small_end.y) >= 0
            and Int(box.small_end.z) >= 0,
            "boxarray box lower bound should stay in the domain",
        )
        expect(
            Int(box.big_end.x) < DOMAIN_EXTENT
            and Int(box.big_end.y) < DOMAIN_EXTENT
            and Int(box.big_end.z) < DOMAIN_EXTENT,
            "boxarray box upper bound should stay in the domain",
        )
        expect(
            Int(box.big_end.x) - Int(box.small_end.x) + 1 <= 32,
            "boxarray x-extent should respect max_size",
        )
        expect(
            Int(box.big_end.y) - Int(box.small_end.y) + 1 <= 32,
            "boxarray y-extent should respect max_size",
        )
        expect(
            Int(box.big_end.z) - Int(box.small_end.z) + 1 <= 32,
            "boxarray z-extent should respect max_size",
        )
        total_cells += box_cells(box)

    expect(
        total_cells == DOMAIN_EXTENT * DOMAIN_EXTENT * DOMAIN_EXTENT,
        "boxarray should cover the full domain",
    )

    var distmap = DistributionMapping(runtime, boxarray)
    _ = distmap

    var geometry = Geometry(runtime, domain)
    expect_box(
        geometry.domain(),
        0,
        0,
        0,
        DOMAIN_EXTENT - 1,
        DOMAIN_EXTENT - 1,
        DOMAIN_EXTENT - 1,
        "geometry domain mismatch",
    )

    var prob_domain = geometry.prob_domain()
    expect_close(prob_domain.lo_x, 0.0, 1.0e-12, "prob_domain.lo_x mismatch")
    expect_close(prob_domain.lo_y, 0.0, 1.0e-12, "prob_domain.lo_y mismatch")
    expect_close(prob_domain.lo_z, 0.0, 1.0e-12, "prob_domain.lo_z mismatch")
    expect_close(prob_domain.hi_x, 1.0, 1.0e-12, "prob_domain.hi_x mismatch")
    expect_close(prob_domain.hi_y, 1.0, 1.0e-12, "prob_domain.hi_y mismatch")
    expect_close(prob_domain.hi_z, 1.0, 1.0e-12, "prob_domain.hi_z mismatch")

    var cell_size = geometry.cell_size()
    var expected_cell = 1.0 / Float64(DOMAIN_EXTENT)
    expect_close(cell_size.x, expected_cell, 1.0e-12, "cell_size.x mismatch")
    expect_close(cell_size.y, expected_cell, 1.0e-12, "cell_size.y mismatch")
    expect_close(cell_size.z, expected_cell, 1.0e-12, "cell_size.z mismatch")

    var periodicity = geometry.periodicity()
    expect_intvect(periodicity, 0, 0, 0, "geometry periodicity mismatch")

    print("runtime_geometry_test: ok")
