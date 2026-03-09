#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AMREX_MOJO_ABI_VERSION 1

typedef struct amrex_mojo_boxarray amrex_mojo_boxarray_t;
typedef struct amrex_mojo_distmap amrex_mojo_distmap_t;
typedef struct amrex_mojo_geometry amrex_mojo_geometry_t;
typedef struct amrex_mojo_mfiter amrex_mojo_mfiter_t;
typedef struct amrex_mojo_multifab amrex_mojo_multifab_t;
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
    double lo[3];
    double hi[3];
} amrex_mojo_realbox_3d;

typedef struct amrex_mojo_array4_view_f64
{
    double* data;
    int32_t lo[3];
    int32_t hi[3];
    int64_t stride[4];
    int32_t ncomp;
} amrex_mojo_array4_view_f64;

int32_t amrex_mojo_abi_version(void);
const char* amrex_mojo_last_error_message(void);

amrex_mojo_status_code_t amrex_mojo_initialize(
    int32_t argc,
    const char* const* argv,
    int32_t use_parmparse
);
amrex_mojo_status_code_t amrex_mojo_finalize(void);
int32_t amrex_mojo_initialized(void);

int32_t amrex_mojo_parallel_nprocs(void);
int32_t amrex_mojo_parallel_myproc(void);
int32_t amrex_mojo_parallel_ioprocessor(void);
int32_t amrex_mojo_parallel_ioprocessor_number(void);

amrex_mojo_status_code_t amrex_mojo_boxarray_create_from_box(
    const amrex_mojo_box_3d* domain,
    amrex_mojo_boxarray_t** out_boxarray
);
amrex_mojo_status_code_t amrex_mojo_boxarray_destroy(amrex_mojo_boxarray_t* boxarray);
amrex_mojo_status_code_t amrex_mojo_boxarray_max_size(
    amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_intvect_3d* max_size
);
amrex_mojo_status_code_t amrex_mojo_boxarray_size(
    const amrex_mojo_boxarray_t* boxarray,
    int64_t* out_size
);

amrex_mojo_status_code_t amrex_mojo_distmap_create_from_boxarray(
    const amrex_mojo_boxarray_t* boxarray,
    amrex_mojo_distmap_t** out_distmap
);
amrex_mojo_status_code_t amrex_mojo_distmap_destroy(amrex_mojo_distmap_t* distmap);

amrex_mojo_status_code_t amrex_mojo_geometry_create(
    const amrex_mojo_box_3d* domain,
    amrex_mojo_geometry_t** out_geometry
);
amrex_mojo_status_code_t amrex_mojo_geometry_destroy(amrex_mojo_geometry_t* geometry);

amrex_mojo_status_code_t amrex_mojo_multifab_create(
    const amrex_mojo_boxarray_t* boxarray,
    const amrex_mojo_distmap_t* distmap,
    int32_t ncomp,
    const amrex_mojo_intvect_3d* ngrow,
    amrex_mojo_multifab_t** out_multifab
);
amrex_mojo_status_code_t amrex_mojo_multifab_destroy(amrex_mojo_multifab_t* multifab);
amrex_mojo_status_code_t amrex_mojo_multifab_ncomp(
    const amrex_mojo_multifab_t* multifab,
    int32_t* out_ncomp
);
amrex_mojo_status_code_t amrex_mojo_multifab_set_val(
    amrex_mojo_multifab_t* multifab,
    double value,
    int32_t start_comp,
    int32_t ncomp
);
amrex_mojo_status_code_t amrex_mojo_multifab_array4(
    amrex_mojo_multifab_t* multifab,
    amrex_mojo_mfiter_t* mfiter,
    amrex_mojo_array4_view_f64* out_view
);

amrex_mojo_status_code_t amrex_mojo_mfiter_create(
    amrex_mojo_multifab_t* multifab,
    amrex_mojo_mfiter_t** out_mfiter
);
amrex_mojo_status_code_t amrex_mojo_mfiter_destroy(amrex_mojo_mfiter_t* mfiter);
int32_t amrex_mojo_mfiter_is_valid(const amrex_mojo_mfiter_t* mfiter);
amrex_mojo_status_code_t amrex_mojo_mfiter_next(amrex_mojo_mfiter_t* mfiter);

amrex_mojo_status_code_t amrex_mojo_parmparse_create(
    const char* prefix,
    amrex_mojo_parmparse_t** out_parmparse
);
amrex_mojo_status_code_t amrex_mojo_parmparse_destroy(amrex_mojo_parmparse_t* parmparse);
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
