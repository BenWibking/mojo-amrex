# Mojo C FFI struct-by-value reproducer

This is a minimal reproducer for a suspected Mojo C FFI ABI bug with a small
C struct passed by value after several pointer/integer arguments.

The relevant C signature is:

```c
typedef struct int3_t {
    int32_t x;
    int32_t y;
    int32_t z;
} int3_t;

int check_struct_after_five(
    void* p0,
    void* p1,
    int32_t a,
    int32_t b,
    int32_t c,
    int3_t value
);
```

On the affected toolchain, a native C caller passes `(11, 22, 33)` correctly,
but the equivalent Mojo `thin abi("C")` call can corrupt `value`.

## Run

From this directory:

```sh
make
./native_check
mojo ffi_struct_repro.mojo
```

From the repo root with this Pixi environment:

```sh
pixi run make -C issues/mojo-c-ffi-struct-by-value
pixi run -x mojo issues/mojo-c-ffi-struct-by-value/ffi_struct_repro.mojo
```

Expected native C output:

```text
native C status=0 observed=(101, 202, 303; 11, 22, 33)
```

Expected Mojo output if the ABI is correct:

```text
struct_early status= 0
observed=(a= 101 , b= 202 , c= 303 , x= 11 , y= 22 , z= 33 )
scalars_after_five status= 0
observed=(a= 101 , b= 202 , c= 303 , x= 11 , y= 22 , z= 33 )
struct_after_five status= 0
observed=(a= 101 , b= 202 , c= 303 , x= 11 , y= 22 , z= 33 )
all checks passed
```

Observed Mojo output on the affected toolchain:

```text
struct_early status= 0
observed=(a= 101 , b= 202 , c= 303 , x= 11 , y= 22 , z= 33 )
scalars_after_five status= 0
observed=(a= 101 , b= 202 , c= 303 , x= 11 , y= 22 , z= 33 )
struct_after_five status= 30
observed=(a= 101 , b= 202 , c= 303 , x= 33 , y= 0 , z= <garbage> )
```

## Hypothesis

This appears to be triggered by the x86-64 System V ABI rule for by-value
aggregate arguments. Pointers and `int32_t` values use the integer argument
register class, and only six integer argument registers are available. The
`int3_t` aggregate is 12 bytes, so it is classified as two integer eightbytes
and needs two integer argument slots when passed by value.

In `check_struct_after_five`, the two pointer arguments and three `int32_t`
arguments consume five integer registers before `int3_t value` is passed. Only
one integer register remains. Under the ABI, an aggregate that cannot fit
entirely in the remaining registers is passed entirely on the stack. The
working scalar variant can still split individual scalar arguments between the
last register and the stack, but the aggregate cannot be split that way.

The observed Mojo corruption is consistent with the FFI lowering not handling
that rollback-to-stack case correctly for a small by-value struct after enough
preceding integer-class arguments.

The practical workaround is to avoid passing this aggregate by value across
the Mojo C FFI boundary and expose scalar `x, y, z` arguments instead.
