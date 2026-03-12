SHELL := /bin/sh

CLANG ?= clang
SDKROOT ?= $(shell xcrun --sdk macosx --show-sdk-path 2>/dev/null)
OBJCFLAGS ?= -std=c11 -fobjc-arc
FRAMEWORKS := -framework Foundation -framework Metal

SRC := apple_silicon_zero_copy_host_buffer_gpu_repro_metal_malloc.m
OUT_DIR := .
BIN := $(OUT_DIR)/apple_silicon_zero_copy_host_buffer_gpu_repro_metal

ifneq ($(SDKROOT),)
SDK_FLAGS := -isysroot $(SDKROOT)
endif

.PHONY: all build run clean

all: build

build: $(BIN)

$(BIN): $(SRC) | $(OUT_DIR)
	$(CLANG) $(OBJCFLAGS) $(SDK_FLAGS) $(SRC) $(FRAMEWORKS) -o $@

$(OUT_DIR):
	mkdir -p $@

run: $(BIN)
	./$(BIN)

clean:
	rm -rf $(OUT_DIR)
