SHELL := /bin/sh

CLANG ?= clang
SDKROOT ?= $(shell xcrun --sdk macosx --show-sdk-path 2>/dev/null)
OBJCFLAGS ?= -std=c11 -fobjc-arc
FRAMEWORKS := -framework Foundation -framework Metal

SRC := metal_zero_copy_tests.m
OUT_DIR := .
BIN := $(OUT_DIR)/metal_zero_copy_tests
ARGS ?=

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
	./$(BIN) $(ARGS)

clean:
	rm -rf $(OUT_DIR)
