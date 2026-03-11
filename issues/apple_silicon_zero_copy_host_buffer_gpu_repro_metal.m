/*
Standalone pure-Metal reproducer for the Mojo issue in
issues/apple_silicon_zero_copy_host_buffer_gpu_repro.mojo.

Build:
  clang -std=c11 -fobjc-arc \
    issues/apple_silicon_zero_copy_host_buffer_gpu_repro_metal.m \
    -framework Foundation -framework Metal \
    -o /tmp/apple_silicon_zero_copy_host_buffer_gpu_repro_metal

Run:
  /tmp/apple_silicon_zero_copy_host_buffer_gpu_repro_metal
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
static const NSUInteger kBlockSize = 256;
static const float kFillValue = 42.0f;

static NSString *const kKernelSource =
    @"#include <metal_stdlib>\n"
    @"using namespace metal;\n"
    @"kernel void fill_buffer(\n"
    @"    device float *dst [[buffer(0)]],\n"
    @"    constant uint &count [[buffer(1)]],\n"
    @"    constant float &value [[buffer(2)]],\n"
    @"    uint gid [[thread_position_in_grid]]) {\n"
    @"  if (gid < count) {\n"
    @"    dst[gid] = value;\n"
    @"  }\n"
    @"}\n";

static size_t round_up_to_page_size(size_t bytes) {
    const size_t page_size = (size_t)getpagesize();
    return ((bytes + page_size - 1) / page_size) * page_size;
}

static float *allocate_page_aligned_zeroed_buffer(size_t bytes) {
    void *storage = NULL;
    const size_t page_size = (size_t)getpagesize();
    const int rc = posix_memalign(&storage, page_size, bytes);
    if (rc != 0) {
        return NULL;
    }
    memset(storage, 0, bytes);
    return (float *)storage;
}

static double sum_buffer(const float *data, uint32_t count) {
    double total = 0.0;
    for (uint32_t i = 0; i < count; ++i) {
        total += (double)data[i];
    }
    return total;
}

static BOOL nearly_equal(double lhs, double rhs) {
    return fabs(lhs - rhs) <= 1.0e-9;
}

static void print_error(const char *prefix, NSError *error) {
    if (error == nil) {
        fprintf(stderr, "%s\n", prefix);
        return;
    }
    fprintf(stderr, "%s: %s\n", prefix, error.localizedDescription.UTF8String);
}

static id<MTLComputePipelineState>
create_fill_pipeline(id<MTLDevice> device) {
    NSError *error = nil;
    id<MTLLibrary> library =
        [device newLibraryWithSource:kKernelSource options:nil error:&error];
    if (library == nil) {
        print_error("failed to compile Metal library", error);
        return nil;
    }

    id<MTLFunction> function = [library newFunctionWithName:@"fill_buffer"];
    if (function == nil) {
        fprintf(stderr, "failed to find fill_buffer entry point\n");
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

static void encode_fill(
    id<MTLCommandBuffer> command_buffer,
    id<MTLComputePipelineState> pipeline,
    id<MTLBuffer> dst,
    uint32_t element_count,
    float value
) {
    id<MTLComputeCommandEncoder> encoder =
        [command_buffer computeCommandEncoder];
    [encoder setComputePipelineState:pipeline];
    [encoder setBuffer:dst offset:0 atIndex:0];
    [encoder setBytes:&element_count length:sizeof(element_count) atIndex:1];
    [encoder setBytes:&value length:sizeof(value) atIndex:2];

    NSUInteger threads_per_threadgroup =
        MIN(kBlockSize, pipeline.maxTotalThreadsPerThreadgroup);
    const NSUInteger execution_width = pipeline.threadExecutionWidth;
    if (execution_width > 0) {
        threads_per_threadgroup =
            MAX(execution_width,
                (threads_per_threadgroup / execution_width) * execution_width);
    }

    [encoder dispatchThreads:MTLSizeMake(element_count, 1, 1)
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

        id<MTLComputePipelineState> pipeline = create_fill_pipeline(device);
        if (pipeline == nil) {
            return 1;
        }

        const size_t payload_bytes = (size_t)kElementCount * sizeof(float);
        const size_t allocation_bytes = round_up_to_page_size(payload_bytes);

        float *zero_copy_host_data =
            allocate_page_aligned_zeroed_buffer(allocation_bytes);
        float *staged_copy_host_data =
            allocate_page_aligned_zeroed_buffer(allocation_bytes);
        if (zero_copy_host_data == NULL || staged_copy_host_data == NULL) {
            fprintf(stderr, "failed to allocate page-aligned host buffers\n");
            free(zero_copy_host_data);
            free(staged_copy_host_data);
            return 1;
        }

        id<MTLBuffer> zero_copy_buffer =
            [device newBufferWithBytesNoCopy:zero_copy_host_data
                                      length:allocation_bytes
                                     options:MTLResourceStorageModeShared
                                 deallocator:nil];
        id<MTLBuffer> staged_copy_buffer =
            [device newBufferWithBytesNoCopy:staged_copy_host_data
                                      length:allocation_bytes
                                     options:MTLResourceStorageModeShared
                                 deallocator:nil];
        id<MTLBuffer> device_buffer =
            [device newBufferWithLength:payload_bytes
                                options:MTLResourceStorageModeShared];

        if (zero_copy_buffer == nil ||
            staged_copy_buffer == nil ||
            device_buffer == nil) {
            fprintf(stderr, "failed to create Metal buffers\n");
            free(zero_copy_host_data);
            free(staged_copy_host_data);
            return 1;
        }

        zero_copy_buffer.label = @"zero-copy-host-buffer";
        staged_copy_buffer.label = @"staged-copy-host-buffer";
        device_buffer.label = @"metal-owned-buffer";

        id<MTLCommandBuffer> zero_copy_command = [command_queue commandBuffer];
        zero_copy_command.label = @"zero-copy-direct-fill";
        encode_fill(
            zero_copy_command,
            pipeline,
            zero_copy_buffer,
            kElementCount,
            kFillValue
        );
        if (!commit_and_wait(
                zero_copy_command,
                "zero-copy Metal compute dispatch")) {
            free(zero_copy_host_data);
            free(staged_copy_host_data);
            return 1;
        }

        id<MTLCommandBuffer> staged_command = [command_queue commandBuffer];
        staged_command.label = @"staged-fill-and-copy-back";
        encode_fill(
            staged_command,
            pipeline,
            device_buffer,
            kElementCount,
            kFillValue
        );

        id<MTLBlitCommandEncoder> blit = [staged_command blitCommandEncoder];
        [blit copyFromBuffer:device_buffer
                sourceOffset:0
                    toBuffer:staged_copy_buffer
           destinationOffset:0
                        size:payload_bytes];
        [blit endEncoding];

        if (!commit_and_wait(
                staged_command,
                "staged Metal compute dispatch + copy-back")) {
            free(zero_copy_host_data);
            free(staged_copy_host_data);
            return 1;
        }

        const double expected_sum = (double)kElementCount * (double)kFillValue;
        const double zero_copy_sum =
            sum_buffer(zero_copy_host_data, kElementCount);
        const double device_buffer_sum =
            sum_buffer((const float *)device_buffer.contents, kElementCount);
        const double staged_copy_sum =
            sum_buffer(staged_copy_host_data, kElementCount);

        const BOOL zero_copy_matches = nearly_equal(zero_copy_sum, expected_sum);
        const BOOL device_buffer_matches =
            nearly_equal(device_buffer_sum, expected_sum);
        const BOOL staged_copy_matches =
            nearly_equal(staged_copy_sum, expected_sum);

        printf("device=%s\n", device.name.UTF8String);
        printf("elements=%u\n", kElementCount);
        printf("expected_sum=%.1f\n", expected_sum);
        printf("zero_copy_sum=%.1f\n", zero_copy_sum);
        printf("device_buffer_sum=%.1f\n", device_buffer_sum);
        printf("staged_copy_sum=%.1f\n", staged_copy_sum);
        printf("zero_copy_contents_matches_host_ptr=%s\n",
               zero_copy_buffer.contents == zero_copy_host_data ? "true" : "false");
        printf("staged_copy_contents_matches_host_ptr=%s\n",
               staged_copy_buffer.contents == staged_copy_host_data ? "true" : "false");
        printf("zero_copy_matches_expected=%s\n",
               zero_copy_matches ? "true" : "false");
        printf("device_buffer_matches_expected=%s\n",
               device_buffer_matches ? "true" : "false");
        printf("staged_copy_matches_expected=%s\n",
               staged_copy_matches ? "true" : "false");

        free(zero_copy_host_data);
        free(staged_copy_host_data);

        return (zero_copy_matches &&
                device_buffer_matches &&
                staged_copy_matches)
                   ? 0
                   : 2;
    }
}
