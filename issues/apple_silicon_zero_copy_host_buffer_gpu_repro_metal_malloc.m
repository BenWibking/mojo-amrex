/*
Minimal proof-of-concept for zero-copy host buffer access from a Metal kernel
using malloc() for the host allocation.

Build:
  clang -std=c11 -fobjc-arc \
    apple_silicon_zero_copy_host_buffer_gpu_repro_metal_malloc.m \
    -framework Foundation -framework Metal \
    -o apple_silicon_zero_copy_host_buffer_gpu_repro_metal_malloc

Run:
  ./apple_silicon_zero_copy_host_buffer_gpu_repro_metal_malloc
*/

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const uint32_t kElementCount = 4096;
static const NSUInteger kThreadgroupSize = 256;
static const float kScale = 2.0f;
static const float kBias = 1.0f;

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

static float *allocate_malloc_buffer(size_t bytes) {
    return (float *)malloc(bytes);
}

static void initialize_host_data(float *data, uint32_t count) {
    for (uint32_t i = 0; i < count; ++i) {
        data[i] = (float)i;
    }
}

static BOOL verify_host_data(
    const float *data,
    uint32_t count,
    float scale,
    float bias
) {
    for (uint32_t i = 0; i < count; ++i) {
        const float expected = (float)i * scale + bias;
        if (fabsf(data[i] - expected) > 1.0e-6f) {
            fprintf(stderr,
                    "verification failed at index %u: got %.6f expected %.6f\n",
                    i,
                    data[i],
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

int main(void) {
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

        const size_t payload_bytes = (size_t)kElementCount * sizeof(float);
        float *host_data = allocate_malloc_buffer(payload_bytes);
        if (host_data == NULL) {
            fprintf(stderr, "failed to allocate host buffer with malloc\n");
            return 1;
        }
        initialize_host_data(host_data, kElementCount);

        id<MTLBuffer> zero_copy_buffer =
            [device newBufferWithBytesNoCopy:host_data
                                      length:payload_bytes
                                     options:MTLResourceStorageModeShared
                                 deallocator:nil];
        if (zero_copy_buffer == nil) {
            fprintf(stderr, "failed to create host-backed Metal buffer\n");
            free(host_data);
            return 1;
        }
        zero_copy_buffer.label = @"host-backed-zero-copy-buffer-malloc";

        id<MTLCommandBuffer> command_buffer = [command_queue commandBuffer];
        command_buffer.label = @"zero-copy-kernel-access-malloc";
        encode_kernel(
            command_buffer,
            pipeline,
            zero_copy_buffer,
            kElementCount,
            kScale,
            kBias
        );
        if (!commit_and_wait(command_buffer, "zero-copy Metal kernel dispatch")) {
            free(host_data);
            return 1;
        }

        const size_t page_size = (size_t)getpagesize();
        const size_t host_ptr_mod_page =
            (size_t)((uintptr_t)host_data % (uintptr_t)page_size);
        const BOOL contents_match = (zero_copy_buffer.contents == host_data);
        const BOOL verification_passed =
            verify_host_data(host_data, kElementCount, kScale, kBias);

        printf("device=%s\n", device.name.UTF8String);
        printf("elements=%u\n", kElementCount);
        printf("payload_bytes=%zu\n", payload_bytes);
        printf("host_ptr_page_aligned=%s\n",
               host_ptr_mod_page == 0 ? "true" : "false");
        printf("host_ptr_mod_page=%zu\n", host_ptr_mod_page);
        printf("buffer_contents_matches_host_ptr=%s\n",
               contents_match ? "true" : "false");
        printf("first_value=%.1f\n", host_data[0]);
        printf("last_value=%.1f\n", host_data[kElementCount - 1]);
        printf("verification_passed=%s\n",
               verification_passed ? "true" : "false");

        free(host_data);
        return (contents_match && verification_passed) ? 0 : 2;
    }
}
