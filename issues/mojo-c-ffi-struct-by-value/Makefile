CC ?= cc
CFLAGS ?= -O0 -g -Wall -Wextra -fPIC

.PHONY: all clean run-native run-mojo

all: libffi_struct_repro.so native_check

libffi_struct_repro.so: ffi_struct_repro.c
	$(CC) $(CFLAGS) -shared -o $@ $<

native_check: ffi_struct_repro.c
	$(CC) $(CFLAGS) -DREPRO_NATIVE_MAIN -o $@ $<

run-native: native_check
	./native_check

run-mojo: libffi_struct_repro.so
	mojo ffi_struct_repro.mojo

clean:
	rm -f libffi_struct_repro.so native_check
