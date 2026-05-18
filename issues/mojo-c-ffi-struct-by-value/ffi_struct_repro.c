#include <stdint.h>
#include <stdio.h>

typedef struct int3_t {
    int32_t x;
    int32_t y;
    int32_t z;
} int3_t;

static int token_a_storage = 0;
static int token_b_storage = 0;

static int32_t last_a = 0;
static int32_t last_b = 0;
static int32_t last_c = 0;
static int32_t last_x = 0;
static int32_t last_y = 0;
static int32_t last_z = 0;

void* token_a(void)
{
    return &token_a_storage;
}

void* token_b(void)
{
    return &token_b_storage;
}

int32_t last_arg_a(void) { return last_a; }
int32_t last_arg_b(void) { return last_b; }
int32_t last_arg_c(void) { return last_c; }
int32_t last_arg_x(void) { return last_x; }
int32_t last_arg_y(void) { return last_y; }
int32_t last_arg_z(void) { return last_z; }

static int check_common(
    void* p0,
    void* p1,
    int32_t a,
    int32_t b,
    int32_t c,
    int32_t x,
    int32_t y,
    int32_t z
)
{
    last_a = a;
    last_b = b;
    last_c = c;
    last_x = x;
    last_y = y;
    last_z = z;

    if (p0 != &token_a_storage) {
        return 10;
    }
    if (p1 != &token_b_storage) {
        return 11;
    }
    if (a != 101 || b != 202 || c != 303) {
        return 20;
    }
    if (x != 11 || y != 22 || z != 33) {
        return 30;
    }
    return 0;
}

int check_struct_early(void* p0, void* p1, int3_t value)
{
    return check_common(p0, p1, 101, 202, 303, value.x, value.y, value.z);
}

int check_struct_after_five(
    void* p0,
    void* p1,
    int32_t a,
    int32_t b,
    int32_t c,
    int3_t value
)
{
    return check_common(p0, p1, a, b, c, value.x, value.y, value.z);
}

int check_scalars_after_five(
    void* p0,
    void* p1,
    int32_t a,
    int32_t b,
    int32_t c,
    int32_t x,
    int32_t y,
    int32_t z
)
{
    return check_common(p0, p1, a, b, c, x, y, z);
}

#ifdef REPRO_NATIVE_MAIN
int main(void)
{
    int status = check_struct_after_five(
        token_a(),
        token_b(),
        101,
        202,
        303,
        (int3_t){11, 22, 33}
    );
    printf("native C status=%d observed=(%d, %d, %d; %d, %d, %d)\n",
           status, last_a, last_b, last_c, last_x, last_y, last_z);
    return status;
}
#endif
