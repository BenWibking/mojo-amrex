CC ?= cc
CPPFLAGS ?=
CFLAGS ?= -O0 -g -Wall -Wextra
PICFLAGS ?= -fPIC
LDFLAGS ?=
LIBS ?=

.PHONY: all clean run-native run-mojo

all: libffi_struct_repro.so native_check

libffi_struct_repro.so: ffi_struct_repro.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(PICFLAGS) -shared $(LDFLAGS) -o $@ $< $(LIBS)

native_check: ffi_struct_repro.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -DREPRO_NATIVE_MAIN $(LDFLAGS) -o $@ $< $(LIBS)

run-native: native_check
	./native_check

run-mojo: libffi_struct_repro.so
	mojo ffi_struct_repro.mojo

clean:
	rm -f libffi_struct_repro.so native_check
