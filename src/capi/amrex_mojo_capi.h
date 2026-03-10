#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AMREX_MOJO_ABI_VERSION 1

typedef struct amrex_mojo_runtime amrex_mojo_runtime_t;
typedef struct amrex_mojo_boxarray amrex_mojo_boxarray_t;
typedef struct amrex_mojo_distmap amrex_mojo_distmap_t;
typedef struct amrex_mojo_geometry amrex_mojo_geometry_t;
typedef struct amrex_mojo_multifab amrex_mojo_multifab_t;
typedef struct amrex_mojo_mfiter amrex_mojo_mfiter_t;
typedef struct amrex_mojo_parmparse amrex_mojo_parmparse_t;

typedef enum amrex_mojo_status_code
{
    AMREX_MOJO_STATUS_OK = 0,
    AMREX_MOJO_STATUS_UNIMPLEMENTED = 1,
    AMREX_MOJO_STATUS_INVALID_ARGUMENT = 2,
    AMREX_MOJO_STATUS_INTERNAL_ERROR = 3
} amrex_mojo_status_code_t;

typedef struct amrex_mojo_intvect_3d
{
    int32_t x;
    int32_t y;
    int32_t z;
} amrex_mojo_intvect_3d;

typedef struct amrex_mojo_box_3d
{
    amrex_mojo_intvect_3d small_end;
    amrex_mojo_intvect_3d big_end;
    amrex_mojo_intvect_3d nodal;
} amrex_mojo_box_3d;

typedef struct amrex_mojo_realbox_3d
{
    double lo_x;
    double lo_y;
    double lo_z;
    double hi_x;
    double hi_y;
    double hi_z;
} amrex_mojo_realbox_3d;

typedef struct amrex_mojo_realvect_3d
{
    double x;
    double y;
    double z;
} amrex_mojo_realvect_3d;

typedef struct amrex_mojo_array4_view_f64
{
    double* data;
    int32_t lo_x;
    int32_t lo_y;
    int32_t lo_z;
    int32_t hi_x;
    int32_t hi_y;
    int32_t hi_z;
    int64_t stride_i;
    int64_t stride_j;
    int64_t stride_k;
    int64_t stride_n;
    int32_t ncomp;
} amrex_mojo_array4_view_f64;

int32_t amrex_mojo_abi_version(void);
const char* amrex_mojo_last_error_message(void);

amrex_mojo_runtime_t* amrex_mojo_runtime_create(
    int32_t argc,
    const char* const* argv,
    int32_t use_parmparse
);
amrex_mojo_runtime_t* amrex_mojo_runtime_create_default(void);
void amrex_mojo_runtime_destroy(amrex_mojo_runtime_t* runtime);
int32_t amrex_mojo_runtime_initialized(const amrex_mojo_runtime_t* runtime);

int32_t amrex_mojo_parallel_nprocs(void);
int32_t amrex_mojo_parallel_myproc(void);
int32_t amrex_mojo_parallel_ioprocessor(void);
int32_t amrex_mojo_parallel_ioprocessor_number(void);

amrex_mojo_boxarray_t* amrex_mojo_boxarray_create_from_box(
    amrex_mojo_runtime_t* runtime,
    amrex_mojo_box_3d domain
);
amrex_mojo_boxarray_t* amrex_mojo_boxarray_create_from_bounds(
    amrex_mojo_runtime_t* runtime,
    int32_t lo_x,
    int32_t lo_y,
    int32_t lo_z,
    int32_t hi_x,
    int32_t hi_y,
    int32_t hi_z,
    int32_t nodal_x,
    int32_t nodal_y,
    int32_t nodal_z
);
void amrex_mojo_boxarray_destroy(amrex_mojo_boxarray_t* boxarray);
amrex_mojo_status_code_t amrex_mojo_boxarray_max_size(
    amrex_mojo_boxarray_t* boxarray,
    amrex_mojo_intvect_3d max_size
);
amrex_mojo_status_code_t amrex_mojo_boxarray_max_size_xyz(
    amrex_mojo_boxarray_t* boxarray,
    int32_t x,
    int32_t y,
    int32_t z
);
int32_t amrex_mojo_boxarray_size(const amrex_mojo_boxarray_t* boxarray);
amrex_mojo_box_3d amrex_mojo_boxarray_box(const amrex_mojo_boxarray_t* boxarray, int32_t index);
amrex_mojo_status_code_t amrex_mojo_boxarray_box_metadata(
    const amrex_mojo_boxarray_t* boxarray,
    int32_t index,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
);

amrex_mojo_distmap_t* amrex_mojo_distmap_create_from_boxarray(
    amrex_mojo_runtime_t* runtime,
    const amrex_mojo_boxarray_t* boxarray
);
void amrex_mojo_distmap_destroy(amrex_mojo_distmap_t* distmap);

amrex_mojo_geometry_t* amrex_mojo_geometry_create(
    amrex_mojo_runtime_t* runtime,
    amrex_mojo_box_3d domain
);
amrex_mojo_geometry_t* amrex_mojo_geometry_create_from_bounds(
    amrex_mojo_runtime_t* runtime,
    int32_t lo_x,
    int32_t lo_y,
    int32_t lo_z,
    int32_t hi_x,
    int32_t hi_y,
    int32_t hi_z,
    int32_t nodal_x,
    int32_t nodal_y,
    int32_t nodal_z
);
void amrex_mojo_geometry_destroy(amrex_mojo_geometry_t* geometry);
amrex_mojo_box_3d amrex_mojo_geometry_domain(const amrex_mojo_geometry_t* geometry);
amrex_mojo_realbox_3d amrex_mojo_geometry_prob_domain(const amrex_mojo_geometry_t* geometry);
amrex_mojo_realvect_3d amrex_mojo_geometry_cell_size(const amrex_mojo_geometry_t* geometry);
amrex_mojo_intvect_3d amrex_mojo_geometry_periodicity(const amrex_mojo_geometry_t* geometry);
amrex_mojo_status_code_t amrex_mojo_geometry_domain_metadata(
    const amrex_mojo_geometry_t* geometry,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
);
amrex_mojo_status_code_t amrex_mojo_geometry_prob_domain_metadata(
    const amrex_mojo_geometry_t* geometry,
    double* out_lo,
    double* out_hi
);
amrex_mojo_status_code_t amrex_mojo_geometry_cell_size_data(
    const amrex_mojo_geometry_t* geometry,
    double* out_cell_size
);
amrex_mojo_status_code_t amrex_mojo_geometry_periodicity_data(
    const amrex_mojo_geometry_t* geometry,
    int32_t* out_periodicity
);

amrex_mojo_multifab_t* amrex_mojo_multifab_create(
    amrex_mojo_runtime_t* runtime,
    const amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_distmap_t* distmap,
    int32_t ncomp,
    amrex_mojo_intvect_3d ngrow
);
amrex_mojo_multifab_t* amrex_mojo_multifab_create_xyz(
    amrex_mojo_runtime_t* runtime,
    const amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_distmap_t* distmap,
    int32_t ncomp,
    int32_t ngrow_x,
    int32_t ngrow_y,
    int32_t ngrow_z
);
void amrex_mojo_multifab_destroy(amrex_mojo_multifab_t* multifab);
int32_t amrex_mojo_multifab_ncomp(const amrex_mojo_multifab_t* multifab);
amrex_mojo_intvect_3d amrex_mojo_multifab_ngrow(const amrex_mojo_multifab_t* multifab);
amrex_mojo_status_code_t amrex_mojo_multifab_set_val(
    amrex_mojo_multifab_t* multifab,
    double value,
    int32_t start_comp,
    int32_t ncomp
);
int32_t amrex_mojo_multifab_tile_count(const amrex_mojo_multifab_t* multifab);
amrex_mojo_box_3d amrex_mojo_multifab_tile_box(
    const amrex_mojo_multifab_t* multifab,
    int32_t tile_index
);
amrex_mojo_box_3d amrex_mojo_multifab_valid_box(
    const amrex_mojo_multifab_t* multifab,
    int32_t tile_index
);
amrex_mojo_array4_view_f64 amrex_mojo_multifab_array4(
    const amrex_mojo_multifab_t* multifab,
    int32_t tile_index
);
double* amrex_mojo_multifab_data_ptr(const amrex_mojo_multifab_t* multifab, int32_t tile_index);
amrex_mojo_status_code_t amrex_mojo_multifab_tile_metadata(
    const amrex_mojo_multifab_t* multifab,
    int32_t tile_index,
    int32_t* tile_lo,
    int32_t* tile_hi,
    int32_t* valid_lo,
    int32_t* valid_hi,
    int32_t* data_lo,
    int32_t* data_hi,
    int64_t* stride,
    int32_t* out_ncomp
);
amrex_mojo_status_code_t amrex_mojo_multifab_array4_metadata_for_mfiter(
    const amrex_mojo_multifab_t* multifab,
    const amrex_mojo_mfiter_t* mfiter,
    int32_t* data_lo,
    int32_t* data_hi,
    int64_t* stride,
    int32_t* out_ncomp
);
double* amrex_mojo_multifab_data_ptr_for_mfiter(
    const amrex_mojo_multifab_t* multifab,
    const amrex_mojo_mfiter_t* mfiter
);
double amrex_mojo_multifab_min(const amrex_mojo_multifab_t* multifab, int32_t comp);
double amrex_mojo_multifab_max(const amrex_mojo_multifab_t* multifab, int32_t comp);
double amrex_mojo_multifab_sum(const amrex_mojo_multifab_t* multifab, int32_t comp);
double amrex_mojo_multifab_norm0(const amrex_mojo_multifab_t* multifab, int32_t comp);
double amrex_mojo_multifab_norm1(const amrex_mojo_multifab_t* multifab, int32_t comp);
double amrex_mojo_multifab_norm2(const amrex_mojo_multifab_t* multifab, int32_t comp);
amrex_mojo_status_code_t amrex_mojo_multifab_plus(
    amrex_mojo_multifab_t* multifab,
    double value,
    int32_t start_comp,
    int32_t ncomp,
    amrex_mojo_intvect_3d ngrow
);
amrex_mojo_status_code_t amrex_mojo_multifab_mult(
    amrex_mojo_multifab_t* multifab,
    double value,
    int32_t start_comp,
    int32_t ncomp,
    amrex_mojo_intvect_3d ngrow
);
amrex_mojo_status_code_t amrex_mojo_multifab_copy(
    amrex_mojo_multifab_t* dst_multifab,
    const amrex_mojo_multifab_t* src_multifab,
    int32_t src_comp,
    int32_t dst_comp,
    int32_t ncomp,
    amrex_mojo_intvect_3d ngrow
);
amrex_mojo_status_code_t amrex_mojo_multifab_parallel_copy(
    amrex_mojo_multifab_t* dst_multifab,
    const amrex_mojo_multifab_t* src_multifab,
    const amrex_mojo_geometry_t* geometry,
    int32_t src_comp,
    int32_t dst_comp,
    int32_t ncomp,
    amrex_mojo_intvect_3d src_ngrow,
    amrex_mojo_intvect_3d dst_ngrow
);
amrex_mojo_status_code_t amrex_mojo_multifab_fill_boundary(
    amrex_mojo_multifab_t* multifab,
    const amrex_mojo_geometry_t* geometry,
    int32_t start_comp,
    int32_t ncomp,
    int32_t cross
);
amrex_mojo_status_code_t amrex_mojo_write_single_level_plotfile(
    const amrex_mojo_multifab_t* multifab,
    const amrex_mojo_geometry_t* geometry,
    const char* plotfile,
    double time,
    int32_t level_step
);

amrex_mojo_status_code_t
amrex_mojo_mfiter_create(amrex_mojo_multifab_t* multifab, amrex_mojo_mfiter_t** out_mfiter);
void amrex_mojo_mfiter_destroy(amrex_mojo_mfiter_t* mfiter);
int32_t amrex_mojo_mfiter_is_valid(const amrex_mojo_mfiter_t* mfiter);
amrex_mojo_status_code_t amrex_mojo_mfiter_next(amrex_mojo_mfiter_t* mfiter);
int32_t amrex_mojo_mfiter_index(const amrex_mojo_mfiter_t* mfiter);
int32_t amrex_mojo_mfiter_local_tile_index(const amrex_mojo_mfiter_t* mfiter);
amrex_mojo_status_code_t amrex_mojo_mfiter_tile_box_metadata(
    const amrex_mojo_mfiter_t* mfiter,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
);
amrex_mojo_status_code_t amrex_mojo_mfiter_valid_box_metadata(
    const amrex_mojo_mfiter_t* mfiter,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
);
amrex_mojo_status_code_t amrex_mojo_mfiter_fab_box_metadata(
    const amrex_mojo_mfiter_t* mfiter,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
);
amrex_mojo_status_code_t amrex_mojo_mfiter_growntile_box_metadata(
    const amrex_mojo_mfiter_t* mfiter,
    amrex_mojo_intvect_3d ngrow,
    int32_t* out_small_end,
    int32_t* out_big_end,
    int32_t* out_nodal
);

amrex_mojo_parmparse_t* amrex_mojo_parmparse_create(
    amrex_mojo_runtime_t* runtime,
    const char* prefix
);
void amrex_mojo_parmparse_destroy(amrex_mojo_parmparse_t* parmparse);
amrex_mojo_status_code_t amrex_mojo_parmparse_add_int(
    amrex_mojo_parmparse_t* parmparse,
    const char* name,
    int32_t value
);
amrex_mojo_status_code_t amrex_mojo_parmparse_query_int(
    amrex_mojo_parmparse_t* parmparse,
    const char* name,
    int32_t* out_value,
    int32_t* out_found
);

#ifdef __cplusplus
}
#endif
