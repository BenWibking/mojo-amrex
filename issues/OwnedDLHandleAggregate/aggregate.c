#include <stdint.h>

typedef struct aggregate_3x3
{
    int32_t x0;
    int32_t x1;
    int32_t x2;
    int32_t y0;
    int32_t y1;
    int32_t y2;
    int32_t z0;
    int32_t z1;
    int32_t z2;
} aggregate_3x3;

int32_t sum_aggregate(aggregate_3x3 value)
{
    return value.x0 + value.x1 + value.x2 +
        value.y0 + value.y1 + value.y2 +
        value.z0 + value.z1 + value.z2;
}

int32_t sum_aggregate_pointer(const aggregate_3x3* value)
{
    return sum_aggregate(*value);
}
