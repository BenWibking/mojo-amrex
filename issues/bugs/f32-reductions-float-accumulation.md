# Float32 multifab reductions accumulate per-box partial results in `float`, losing precision relative to the Float64 path

**Severity: Low** (precision/accuracy issue, no crash; affects `sum`, `norm1`, `norm2` on `fMultiFab`)

## Explanation

The f32 reduction helpers in `src/capi/multifab.cpp` declare their per-box
accumulators as `float` and return `float` from the `ReduceSum`/`ReduceMax`
lambdas:

- `reduce_sum_f32` (`multifab.cpp:452`): `float value = 0.0f; ... value += fab(i,j,k,comp);`
- `reduce_norm1_f32` (`multifab.cpp:506`): same pattern with `std::abs`
- `reduce_norm2_f32` (`multifab.cpp:533`): accumulates `cell * cell` in `float`

A default box is 32^3 = 32,768 cells, so a single box's partial sum already loses
several bits to float32 cancellation/rounding before the cross-rank reduction is
performed in `double`. For `norm2`, squaring in `float` additionally overflows to
`inf` for cell values above ~1.8e19 and underflows for small magnitudes, where
upstream `MultiFab::norm2` semantics (accumulate in `Real`) would survive. The
result is reported as a `double`, which suggests more precision than the
computation actually carries. (`min`/`max`/`norm0` are unaffected — those
reductions are exact in any width.)

## Proposed patch

Accumulate in `double` inside the lambdas and reduce over `double` partials:

```cpp
auto reduce_sum_f32(const amrex::fMultiFab& multifab, int32_t comp) -> double
{
    const auto local_sum = amrex::ReduceSum(
        multifab, 0,
        [=] AMREX_GPU_HOST_DEVICE (amrex::Box const& bx,
                                   amrex::Array4<float const> const& fab) noexcept -> double {
            double value = 0.0;
            ...
            value += static_cast<double>(fab(i, j, k, comp));
            ...
            return value;
        });
    double result = local_sum;
    amrex::ParallelDescriptor::ReduceRealSum(result);
    return result;
}
```

and the equivalent change in `reduce_norm1_f32` and `reduce_norm2_f32`
(`value += double(cell) * double(cell)`).
