/*
Metal zero-copy host buffer experiment harness for Apple Silicon.

Build:
  clang -std=c11 -fobjc-arc \
    metal_zero_copy_tests.m \
    -framework Foundation -framework Metal \
    -o metal_zero_copy_tests

Run:
  ./metal_zero_copy_tests
  ./metal_zero_copy_tests --list
  ./metal_zero_copy_tests --case mmap_offset4_len16385
*/

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#define STATIC_STORAGE_BYTES (128 * 1024)
#define STATIC_ALIGNMENT_BYTES (16 * 1024)
#define STATIC_STORAGE_FLOATS (STATIC_STORAGE_BYTES / sizeof(float))

static const NSUInteger kThreadgroupSize = 256;
static const float kScale = 2.0f;
static const float kBias = 1.0f;

static float g_static_storage[STATIC_STORAGE_FLOATS];
static float g_static_aligned_storage[STATIC_STORAGE_FLOATS]
    __attribute__((aligned(STATIC_ALIGNMENT_BYTES)));

static NSString *const kKernelSource =
    @"#include <metal_stdlib>\n"
    @"using namespace metal;\n"
    @"kernel void scale_and_bias(\n"
    @"    device float *data [[buffer(0)]],\n"
    @"    constant uint &count [[buffer(1)]],\n"
    @"    constant float &scale [[buffer(2)]],\n"
    @"    constant float &bias [[buffer(3)]],\n"
    @"    uint gid [[thread_position_in_grid]]) {\n"
    @"  if (gid < count) {\n"
    @"    data[gid] = data[gid] * scale + bias;\n"
    @"  }\n"
    @"}\n";

typedef enum AllocationKind {
    AllocationKindMalloc,
    AllocationKindPageAlignedHeap,
    AllocationKindMmap,
    AllocationKindStack,
    AllocationKindStaticDefault,
    AllocationKindStaticAligned,
} AllocationKind;

typedef enum CleanupKind {
    CleanupKindNone,
    CleanupKindFree,
    CleanupKindMunmap,
} CleanupKind;

typedef struct TestCase {
    const char *name;
    AllocationKind kind;
    uint32_t element_count;
    size_t buffer_length;
    size_t offset_bytes;
    BOOL expect_verification_failure;
} TestCase;

typedef struct HostBacking {
    void *base_ptr;
    void *data_ptr;
    size_t allocation_bytes;
    CleanupKind cleanup_kind;
} HostBacking;

typedef struct CaseResult {
    BOOL buffer_created;
    BOOL contents_match;
    BOOL dispatch_completed;
    BOOL verification_passed;
    BOOL overall_passed;
    size_t host_ptr_mod_page;
    size_t host_ptr_mod_float_alignment;
    BOOL matched_expectation;
} CaseResult;

static const TestCase kTestCases[] = {
    {
        .name = "malloc_exact_page",
        .kind = AllocationKindMalloc,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float),
        .offset_bytes = 0,
    },
    {
        .name = "malloc_len69",
        .kind = AllocationKindMalloc,
        .element_count = 17,
        .buffer_length = 17 * sizeof(float) + 1,
        .offset_bytes = 0,
    },
    {
        .name = "malloc_len16385",
        .kind = AllocationKindMalloc,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float) + 1,
        .offset_bytes = 0,
    },
    {
        .name = "aligned_heap_len69",
        .kind = AllocationKindPageAlignedHeap,
        .element_count = 17,
        .buffer_length = 17 * sizeof(float) + 1,
        .offset_bytes = 0,
    },
    {
        .name = "aligned_heap_len16385",
        .kind = AllocationKindPageAlignedHeap,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float) + 1,
        .offset_bytes = 0,
    },
    {
        .name = "aligned_heap_offset4_len16384",
        .kind = AllocationKindPageAlignedHeap,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float),
        .offset_bytes = 4,
    },
    {
        .name = "aligned_heap_offset1_len16384",
        .kind = AllocationKindPageAlignedHeap,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float),
        .offset_bytes = 1,
        .expect_verification_failure = YES,
    },
    {
        .name = "aligned_heap_offset2_len16384",
        .kind = AllocationKindPageAlignedHeap,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float),
        .offset_bytes = 2,
        .expect_verification_failure = YES,
    },
    {
        .name = "aligned_heap_offset3_len16384",
        .kind = AllocationKindPageAlignedHeap,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float),
        .offset_bytes = 3,
        .expect_verification_failure = YES,
    },
    {
        .name = "aligned_heap_offset64_len69",
        .kind = AllocationKindPageAlignedHeap,
        .element_count = 17,
        .buffer_length = 17 * sizeof(float) + 1,
        .offset_bytes = 64,
    },
    {
        .name = "aligned_heap_offset4092_len16385",
        .kind = AllocationKindPageAlignedHeap,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float) + 1,
        .offset_bytes = 4092,
    },
    {
        .name = "aligned_heap_offset8192_len32769",
        .kind = AllocationKindPageAlignedHeap,
        .element_count = 8192,
        .buffer_length = 8192 * sizeof(float) + 1,
        .offset_bytes = 8192,
    },
    {
        .name = "mmap_len69",
        .kind = AllocationKindMmap,
        .element_count = 17,
        .buffer_length = 17 * sizeof(float) + 1,
        .offset_bytes = 0,
    },
    {
        .name = "mmap_offset4_len16385",
        .kind = AllocationKindMmap,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float) + 1,
        .offset_bytes = 4,
    },
    {
        .name = "mmap_offset1_len16384",
        .kind = AllocationKindMmap,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float),
        .offset_bytes = 1,
        .expect_verification_failure = YES,
    },
    {
        .name = "mmap_offset8192_len32769",
        .kind = AllocationKindMmap,
        .element_count = 8192,
        .buffer_length = 8192 * sizeof(float) + 1,
        .offset_bytes = 8192,
    },
    {
        .name = "stack_len69",
        .kind = AllocationKindStack,
        .element_count = 17,
        .buffer_length = 17 * sizeof(float) + 1,
        .offset_bytes = 0,
    },
    {
        .name = "stack_len16385",
        .kind = AllocationKindStack,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float) + 1,
        .offset_bytes = 0,
    },
    {
        .name = "stack_offset4_len16385",
        .kind = AllocationKindStack,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float) + 1,
        .offset_bytes = 4,
    },
    {
        .name = "stack_offset1_len16384",
        .kind = AllocationKindStack,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float),
        .offset_bytes = 1,
        .expect_verification_failure = YES,
    },
    {
        .name = "stack_offset8192_len32769",
        .kind = AllocationKindStack,
        .element_count = 8192,
        .buffer_length = 8192 * sizeof(float) + 1,
        .offset_bytes = 8192,
    },
    {
        .name = "global_static_default_offset4_len16385",
        .kind = AllocationKindStaticDefault,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float) + 1,
        .offset_bytes = 4,
    },
    {
        .name = "global_static_default_offset1_len16384",
        .kind = AllocationKindStaticDefault,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float),
        .offset_bytes = 1,
        .expect_verification_failure = YES,
    },
    {
        .name = "global_static_default_offset8192_len32769",
        .kind = AllocationKindStaticDefault,
        .element_count = 8192,
        .buffer_length = 8192 * sizeof(float) + 1,
        .offset_bytes = 8192,
    },
    {
        .name = "global_static_aligned_offset4_len16385",
        .kind = AllocationKindStaticAligned,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float) + 1,
        .offset_bytes = 4,
    },
    {
        .name = "global_static_default_len16384",
        .kind = AllocationKindStaticDefault,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float),
        .offset_bytes = 0,
    },
    {
        .name = "global_static_default_len16385",
        .kind = AllocationKindStaticDefault,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float) + 1,
        .offset_bytes = 0,
    },
    {
        .name = "global_static_aligned_len16385",
        .kind = AllocationKindStaticAligned,
        .element_count = 4096,
        .buffer_length = 4096 * sizeof(float) + 1,
        .offset_bytes = 0,
    },
};

static const size_t kTestCaseCount = sizeof(kTestCases) / sizeof(kTestCases[0]);

static void store_float_value(void *data, uint32_t index, float value) {
    memcpy((uint8_t *)data + (size_t)index * sizeof(value), &value, sizeof(value));
}

static float load_float_value(const void *data, uint32_t index) {
    float value = 0.0f;
    memcpy(&value, (const uint8_t *)data + (size_t)index * sizeof(value), sizeof(value));
    return value;
}

static void initialize_host_data(void *data, uint32_t count) {
    for (uint32_t i = 0; i < count; ++i) {
        store_float_value(data, i, (float)i);
    }
}

static BOOL verify_host_data(
    const void *data,
    uint32_t count,
    float scale,
    float bias
) {
    for (uint32_t i = 0; i < count; ++i) {
        const float observed = load_float_value(data, i);
        const float expected = (float)i * scale + bias;
        if (fabsf(observed - expected) > 1.0e-6f) {
            fprintf(stderr,
                    "verification failed at index %u: got %.6f expected %.6f\n",
                    i,
                    observed,
                    expected);
            return NO;
        }
    }
    return YES;
}

static void print_error(const char *prefix, NSError *error) {
    if (error == nil) {
        fprintf(stderr, "%s\n", prefix);
        return;
    }
    fprintf(stderr, "%s: %s\n", prefix, error.localizedDescription.UTF8String);
}

static void dump_bytes_line(const char *label, const void *data, size_t byte_count) {
    printf("%s=", label);
    for (size_t i = 0; i < byte_count; ++i) {
        printf("%s%02x", i == 0 ? "" : " ", ((const uint8_t *)data)[i]);
    }
    printf("\n");
}

static void dump_float_prefix_line(const char *label, const void *data, uint32_t count) {
    const uint32_t shown = count < 4 ? count : 4;
    printf("%s=", label);
    for (uint32_t i = 0; i < shown; ++i) {
        printf("%s%.6f", i == 0 ? "" : " ", load_float_value(data, i));
    }
    printf("\n");
}

static id<MTLComputePipelineState>
create_pipeline(id<MTLDevice> device) {
    NSError *error = nil;
    id<MTLLibrary> library =
        [device newLibraryWithSource:kKernelSource options:nil error:&error];
    if (library == nil) {
        print_error("failed to compile Metal library", error);
        return nil;
    }

    id<MTLFunction> function = [library newFunctionWithName:@"scale_and_bias"];
    if (function == nil) {
        fprintf(stderr, "failed to find scale_and_bias entry point\n");
        return nil;
    }

    id<MTLComputePipelineState> pipeline =
        [device newComputePipelineStateWithFunction:function error:&error];
    if (pipeline == nil) {
        print_error("failed to create Metal compute pipeline", error);
        return nil;
    }

    return pipeline;
}

static void encode_kernel(
    id<MTLCommandBuffer> command_buffer,
    id<MTLComputePipelineState> pipeline,
    id<MTLBuffer> buffer,
    uint32_t count,
    float scale,
    float bias
) {
    id<MTLComputeCommandEncoder> encoder =
        [command_buffer computeCommandEncoder];
    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:buffer offset:0 atIndex:0];
    [encoder setBytes:&count length:sizeof(count) atIndex:1];
    [encoder setBytes:&scale length:sizeof(scale) atIndex:2];
    [encoder setBytes:&bias length:sizeof(bias) atIndex:3];

    NSUInteger threads_per_threadgroup =
        MIN(kThreadgroupSize, pipeline.maxTotalThreadsPerThreadgroup);
    const NSUInteger execution_width = pipeline.threadExecutionWidth;
    if (execution_width > 0) {
        threads_per_threadgroup =
            MAX(execution_width,
                (threads_per_threadgroup / execution_width) * execution_width);
    }

    [encoder dispatchThreads:MTLSizeMake(count, 1, 1)
      threadsPerThreadgroup:MTLSizeMake(threads_per_threadgroup, 1, 1)];
    [encoder endEncoding];
}

static BOOL commit_and_wait(
    id<MTLCommandBuffer> command_buffer,
    const char *description
) {
    [command_buffer commit];
    [command_buffer waitUntilCompleted];

    if (command_buffer.status != MTLCommandBufferStatusCompleted) {
        NSError *error = command_buffer.error;
        if (error != nil) {
            fprintf(stderr, "%s failed: %s\n",
                    description,
                    error.localizedDescription.UTF8String);
        } else {
            fprintf(stderr, "%s failed with status %ld\n",
                    description,
                    (long)command_buffer.status);
        }
        return NO;
    }

    return YES;
}

static const char *allocation_kind_name(AllocationKind kind) {
    switch (kind) {
        case AllocationKindMalloc:
            return "malloc";
        case AllocationKindPageAlignedHeap:
            return "page_aligned_heap";
        case AllocationKindMmap:
            return "mmap";
        case AllocationKindStack:
            return "stack";
        case AllocationKindStaticDefault:
            return "static_default";
        case AllocationKindStaticAligned:
            return "static_aligned";
    }

    return "unknown";
}

static size_t round_up(size_t value, size_t alignment) {
    if (alignment == 0) {
        return value;
    }
    const size_t remainder = value % alignment;
    if (remainder == 0) {
        return value;
    }
    return value + alignment - remainder;
}

static size_t required_bytes_for_case(const TestCase *test_case) {
    const size_t payload_bytes =
        (size_t)test_case->element_count * sizeof(float);
    const size_t needed_tail =
        test_case->buffer_length > payload_bytes ? test_case->buffer_length
                                                 : payload_bytes;
    return test_case->offset_bytes + needed_tail;
}

static BOOL allocate_dynamic_backing(
    const TestCase *test_case,
    size_t page_size,
    HostBacking *backing
) {
    memset(backing, 0, sizeof(*backing));

    const size_t required_bytes = required_bytes_for_case(test_case);
    if (required_bytes == 0) {
        return NO;
    }

    backing->allocation_bytes = required_bytes;

    switch (test_case->kind) {
        case AllocationKindMalloc: {
            backing->base_ptr = malloc(required_bytes);
            backing->cleanup_kind = CleanupKindFree;
            break;
        }
        case AllocationKindPageAlignedHeap: {
            void *base_ptr = NULL;
            const int rc = posix_memalign(&base_ptr, page_size, required_bytes);
            if (rc != 0) {
                backing->base_ptr = NULL;
            } else {
                backing->base_ptr = base_ptr;
                backing->cleanup_kind = CleanupKindFree;
            }
            break;
        }
        case AllocationKindMmap: {
            const size_t mapped_bytes = round_up(required_bytes, page_size);
            void *base_ptr = mmap(NULL,
                                  mapped_bytes,
                                  PROT_READ | PROT_WRITE,
                                  MAP_PRIVATE | MAP_ANON,
                                  -1,
                                  0);
            if (base_ptr == MAP_FAILED) {
                backing->base_ptr = NULL;
            } else {
                backing->base_ptr = base_ptr;
                backing->allocation_bytes = mapped_bytes;
                backing->cleanup_kind = CleanupKindMunmap;
            }
            break;
        }
        case AllocationKindStack:
        case AllocationKindStaticDefault:
        case AllocationKindStaticAligned:
            return NO;
    }

    if (backing->base_ptr == NULL) {
        return NO;
    }

    backing->data_ptr =
        (void *)((uint8_t *)backing->base_ptr + test_case->offset_bytes);
    return YES;
}

static void cleanup_host_backing(HostBacking *backing) {
    switch (backing->cleanup_kind) {
        case CleanupKindNone:
            break;
        case CleanupKindFree:
            free(backing->base_ptr);
            break;
        case CleanupKindMunmap:
            munmap(backing->base_ptr, backing->allocation_bytes);
            break;
    }

    memset(backing, 0, sizeof(*backing));
}

static CaseResult run_host_pointer_case(
    id<MTLDevice> device,
    id<MTLCommandQueue> command_queue,
    id<MTLComputePipelineState> pipeline,
    const TestCase *test_case,
    void *host_data,
    size_t page_size,
    BOOL dump_bytes
) {
    CaseResult result = {0};
    const size_t snapshot_bytes =
        test_case->buffer_length < 32 ? test_case->buffer_length : 32;
    uint8_t before_bytes[32] = {0};

    initialize_host_data(host_data, test_case->element_count);
    memcpy(before_bytes, host_data, snapshot_bytes);

    if (dump_bytes) {
        dump_float_prefix_line("before_floats", host_data, test_case->element_count);
        dump_bytes_line("before_bytes", host_data, snapshot_bytes);
    }

    id<MTLBuffer> zero_copy_buffer =
        [device newBufferWithBytesNoCopy:host_data
                                  length:test_case->buffer_length
                                 options:MTLResourceStorageModeShared
                             deallocator:nil];
    if (zero_copy_buffer == nil) {
        return result;
    }

    result.buffer_created = YES;
    result.host_ptr_mod_page =
        (size_t)((uintptr_t)host_data % (uintptr_t)page_size);
    result.host_ptr_mod_float_alignment =
        (size_t)((uintptr_t)host_data % (uintptr_t)_Alignof(float));
    result.contents_match = (zero_copy_buffer.contents == host_data);

    id<MTLCommandBuffer> command_buffer = [command_queue commandBuffer];
    command_buffer.label =
        [NSString stringWithFormat:@"zero-copy-%@",
                                   [NSString stringWithUTF8String:test_case->name]];
    encode_kernel(
        command_buffer,
        pipeline,
        zero_copy_buffer,
        test_case->element_count,
        kScale,
        kBias
    );
    result.dispatch_completed =
        commit_and_wait(command_buffer, test_case->name);
    if (!result.dispatch_completed) {
        return result;
    }

    result.verification_passed =
        verify_host_data(host_data, test_case->element_count, kScale, kBias);
    result.overall_passed =
        result.buffer_created && result.contents_match && result.dispatch_completed &&
        result.verification_passed;
    result.matched_expectation =
        result.buffer_created && result.contents_match && result.dispatch_completed &&
        (result.verification_passed != test_case->expect_verification_failure);

    if (dump_bytes) {
        dump_float_prefix_line("after_floats", host_data, test_case->element_count);
        dump_bytes_line("after_bytes", host_data, snapshot_bytes);
        printf("byte_prefix_changed=%s\n",
               memcmp(before_bytes, host_data, snapshot_bytes) == 0 ? "false"
                                                                    : "true");
    }
    return result;
}

static CaseResult run_case(
    id<MTLDevice> device,
    id<MTLCommandQueue> command_queue,
    id<MTLComputePipelineState> pipeline,
    const TestCase *test_case,
    size_t page_size,
    BOOL dump_bytes
) {
    switch (test_case->kind) {
        case AllocationKindStack: {
            float stack_storage[STATIC_STORAGE_FLOATS];
            void *host_data =
                (void *)((uint8_t *)stack_storage + test_case->offset_bytes);
            return run_host_pointer_case(
                device,
                command_queue,
                pipeline,
                test_case,
                host_data,
                page_size,
                dump_bytes
            );
        }
        case AllocationKindStaticDefault: {
            void *host_data =
                (void *)((uint8_t *)g_static_storage + test_case->offset_bytes);
            return run_host_pointer_case(
                device,
                command_queue,
                pipeline,
                test_case,
                host_data,
                page_size,
                dump_bytes
            );
        }
        case AllocationKindStaticAligned: {
            void *host_data =
                (void *)((uint8_t *)g_static_aligned_storage + test_case->offset_bytes);
            return run_host_pointer_case(
                device,
                command_queue,
                pipeline,
                test_case,
                host_data,
                page_size,
                dump_bytes
            );
        }
        case AllocationKindMalloc:
        case AllocationKindPageAlignedHeap:
        case AllocationKindMmap: {
            HostBacking backing = {0};
            if (!allocate_dynamic_backing(test_case, page_size, &backing)) {
                return (CaseResult){0};
            }
            CaseResult result = run_host_pointer_case(
                device,
                command_queue,
                pipeline,
                test_case,
                backing.data_ptr,
                page_size,
                dump_bytes
            );
            cleanup_host_backing(&backing);
            return result;
        }
    }
}

static const TestCase *find_test_case(const char *name) {
    for (size_t i = 0; i < kTestCaseCount; ++i) {
        if (strcmp(kTestCases[i].name, name) == 0) {
            return &kTestCases[i];
        }
    }
    return NULL;
}

static void print_case_result(
    const TestCase *test_case,
    const CaseResult *result
) {
    const size_t payload_bytes =
        (size_t)test_case->element_count * sizeof(float);
    printf("case=%s kind=%s elements=%u payload_bytes=%zu buffer_length=%zu "
           "offset_bytes=%zu host_ptr_mod_page=%zu host_ptr_mod_float=%zu "
           "expected_verification=%s buffer_created=%s "
           "contents_match=%s dispatch_completed=%s verification_passed=%s "
           "overall_passed=%s matched_expectation=%s\n",
           test_case->name,
           allocation_kind_name(test_case->kind),
           test_case->element_count,
           payload_bytes,
           test_case->buffer_length,
           test_case->offset_bytes,
           result->host_ptr_mod_page,
           result->host_ptr_mod_float_alignment,
           test_case->expect_verification_failure ? "false" : "true",
           result->buffer_created ? "true" : "false",
           result->contents_match ? "true" : "false",
           result->dispatch_completed ? "true" : "false",
           result->verification_passed ? "true" : "false",
           result->overall_passed ? "true" : "false",
           result->matched_expectation ? "true" : "false");
}

static void print_usage(const char *program_name) {
    fprintf(stderr,
            "usage: %s [--list | --case NAME [--dump-bytes]]\n",
            program_name);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            fprintf(stderr, "Metal is unavailable on this system\n");
            return 1;
        }

        id<MTLCommandQueue> command_queue = [device newCommandQueue];
        if (command_queue == nil) {
            fprintf(stderr, "failed to create Metal command queue\n");
            return 1;
        }

        id<MTLComputePipelineState> pipeline = create_pipeline(device);
        if (pipeline == nil) {
            return 1;
        }

        const size_t page_size = (size_t)getpagesize();
        size_t passed_count = 0;

        printf("device=%s\n", device.name.UTF8String);
        printf("page_size=%zu\n", page_size);

        BOOL dump_bytes = NO;
        const char *case_name = NULL;

        for (int i = 1; i < argc; ++i) {
            if (strcmp(argv[i], "--list") == 0) {
                if (argc != 2) {
                    print_usage(argv[0]);
                    return 2;
                }
                for (size_t j = 0; j < kTestCaseCount; ++j) {
                    puts(kTestCases[j].name);
                }
                return 0;
            }
            if (strcmp(argv[i], "--dump-bytes") == 0) {
                dump_bytes = YES;
                continue;
            }
            if (strcmp(argv[i], "--case") == 0 && i + 1 < argc) {
                case_name = argv[++i];
                continue;
            }
            print_usage(argv[0]);
            return 2;
        }

        if (case_name != NULL) {
            const TestCase *test_case = find_test_case(case_name);
            if (test_case == NULL) {
                fprintf(stderr, "unknown case: %s\n", case_name);
                return 2;
            }

            const CaseResult result = run_case(
                device,
                command_queue,
                pipeline,
                test_case,
                page_size,
                dump_bytes
            );
            print_case_result(test_case, &result);
            return result.matched_expectation ? 0 : 3;
        }

        if (argc == 1) {
            for (size_t i = 0; i < kTestCaseCount; ++i) {
                const CaseResult result = run_case(
                    device,
                    command_queue,
                    pipeline,
                    &kTestCases[i],
                    page_size,
                    NO
                );
                print_case_result(&kTestCases[i], &result);
                if (result.matched_expectation) {
                    ++passed_count;
                }
            }

            printf("cases_passed=%zu\n", passed_count);
            printf("cases_total=%zu\n", kTestCaseCount);
            printf("suite_passed=%s\n",
                   passed_count == kTestCaseCount ? "true" : "false");
            return passed_count == kTestCaseCount ? 0 : 4;
        }

        print_usage(argv[0]);
        return 2;
    }
}
