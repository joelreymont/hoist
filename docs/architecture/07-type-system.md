# Type System

## What are Types?

Types describe what kind of data a value holds: is it a number? How big? Is it floating-point or integer? Is it a vector of values?

Think of types like categories in a library - they tell you what section (integer, float, vector) a book (value) belongs to.

## Type Representation

**File:** `/Users/joel/Work/hoist/src/ir/types.zig`

Types are encoded as `u16` values:

```zig
pub const Type = packed struct {
    raw: u16,
}
```

**Why u16?** Compact representation - every value carries its type, so smaller = better.

## Scalar Types

### Integer Types

```zig
pub const I8   = Type{ .raw = 0x74 };  // 8-bit integer
pub const I16  = Type{ .raw = 0x75 };  // 16-bit integer
pub const I32  = Type{ .raw = 0x76 };  // 32-bit integer
pub const I64  = Type{ .raw = 0x77 };  // 64-bit integer
pub const I128 = Type{ .raw = 0x78 };  // 128-bit integer
```

**Usage:**
```
v0 = iconst.i32 42      ; v0 has type I32
v1 = iconst.i64 100     ; v1 has type I64
```

### Floating-Point Types

```zig
pub const F16  = Type{ .raw = 0x79 };  // IEEE half-precision (16-bit)
pub const F32  = Type{ .raw = 0x7a };  // IEEE single-precision (32-bit)
pub const F64  = Type{ .raw = 0x7b };  // IEEE double-precision (64-bit)
pub const F128 = Type{ .raw = 0x7c };  // IEEE quad-precision (128-bit)
```

**Usage:**
```
v0 = fconst.f32 3.14    ; v0 has type F32
v1 = fconst.f64 2.718   ; v1 has type F64
```

## Vector Types

Vectors hold multiple values of the same type (SIMD - Single Instruction Multiple Data):

```zig
pub const I8X16  = Type{ .raw = 0xc4 };  // 16 x 8-bit integers
pub const I16X8  = Type{ .raw = 0xb5 };  // 8 x 16-bit integers
pub const I32X4  = Type{ .raw = 0x96 };  // 4 x 32-bit integers
pub const I64X2  = Type{ .raw = 0x87 };  // 2 x 64-bit integers
pub const F32X4  = Type{ .raw = 0x9a };  // 4 x 32-bit floats
pub const F64X2  = Type{ .raw = 0x8b };  // 2 x 64-bit floats
```

**Usage:**
```
v0 = vconst.i32x4 [1, 2, 3, 4]    ; v0 = <1, 2, 3, 4>
v1 = vconst.i32x4 [5, 6, 7, 8]    ; v1 = <5, 6, 7, 8>
v2 = iadd v0, v1                  ; v2 = <6, 8, 10, 12> (parallel add)
```

## Type Encoding

Types use a clever encoding scheme:

```
Type encoding (16 bits):
┌────────────┬──────────┬───────────┐
│ Base (8)   │ Log2LC(4)│ Lane (4)  │
└────────────┴──────────┴───────────┘

Base:    0x70-0x7F for scalars, 0x80+ for vectors
Log2LC:  Log2 of lane count (0=1, 1=2, 2=4, 3=8, 4=16, etc.)
Lane:    Lane type (I8=4, I16=5, I32=6, I64=7, F32=10, etc.)
```

**Example: I32X4**
```
I32X4 = 0x96 = 0b10010110
  Base:    0x80 (vector)
  Log2LC:  2 (2^2 = 4 lanes)
  Lane:    6 (I32)
```

## Type Properties

### bits() - Total size in bits

```zig
Type.I32.bits()   // → 32
Type.I64.bits()   // → 64
Type.I32X4.bits() // → 128 (4 lanes × 32 bits)
Type.F64X2.bits() // → 128 (2 lanes × 64 bits)
```

### bytes() - Size in bytes

```zig
Type.I32.bytes()   // → 4
Type.I64.bytes()   // → 8
Type.I32X4.bytes() // → 16
```

### laneType() - Element type

```zig
Type.I32X4.laneType()  // → Type.I32
Type.F64X2.laneType()  // → Type.F64
Type.I32.laneType()    // → Type.I32 (scalar is its own lane type)
```

### laneCount() - Number of elements

```zig
Type.I32X4.laneCount()  // → 4
Type.F64X2.laneCount()  // → 2
Type.I32.laneCount()    // → 1
```

## Type Checking

The verifier ensures type safety.

**File:** `/Users/joel/Work/hoist/src/ir/verifier.zig`

### Rules

**1. Operations must have matching types:**
```
v0 = iconst.i32 10
v1 = iconst.i64 20
v2 = iadd v0, v1        ; ERROR: Can't add I32 and I64
```

**2. Vector operations require vector types:**
```
v0 = vconst.i32x4 [1,2,3,4]
v1 = iconst.i32 5
v2 = iadd v0, v1        ; ERROR: Can't add vector and scalar
```

**3. Lane types must match:**
```
v0 = vconst.i32x4 [1,2,3,4]
v1 = vconst.i64x2 [5,6]
v2 = iadd v0, v1        ; ERROR: Different lane types (I32 vs I64)
```

### Type Inference

Some operations determine output type from inputs:

```
iadd(I32, I32) → I32        ; Integer add preserves type
imul(I64, I64) → I64
fcmp(F32, F32) → I32        ; Comparison produces integer (boolean)
```

## Register Classes

Types determine which registers to use:

```zig
pub const RegClass = enum {
    int,    // Integer/general-purpose registers
    float,  // Floating-point/SIMD registers
};

fn regClassForType(ty: Type) RegClass {
    if (ty.isInt() or ty.isVector()) return .int;
    if (ty.isFloat()) return .float;
    unreachable;
}
```

**File:** `/Users/joel/Work/hoist/src/machinst/reg.zig`

### ARM64 Example

```
I32, I64, I128 → X/W registers (int class)
F32, F64       → V/D/S registers (float class)
I32X4, F64X2   → V/Q registers (int class for vectors!)
```

Note: SIMD vectors use the "int" class even though they may contain floats. This is because ARM64 vector instructions use V registers but are considered separate from scalar float operations.

## Type Conversions

### Zero Extension (uextend)

Widen unsigned integer by padding with zeros:

```
I8 → I32:   0x42 → 0x00000042
I32 → I64:  0xDEADBEEF → 0x00000000DEADBEEF
```

**IR:**
```
v0 = iconst.i8 0x42
v1 = uextend.i32 v0     ; v1 = 0x00000042 (type I32)
```

### Sign Extension (sextend)

Widen signed integer by copying sign bit:

```
I8 → I32:   0xFF → 0xFFFFFFFF  (negative stays negative)
I8 → I32:   0x42 → 0x00000042  (positive stays positive)
```

**IR:**
```
v0 = iconst.i8 0xFF     ; -1 in I8
v1 = sextend.i32 v0     ; 0xFFFFFFFF (still -1 in I32)
```

### Truncation (ireduce)

Narrow integer by discarding high bits:

```
I32 → I8:   0xDEADBEEF → 0xEF  (keep low 8 bits)
I64 → I32:  0x123456789ABCDEF0 → 0x9ABCDEF0
```

**IR:**
```
v0 = iconst.i32 0xDEADBEEF
v1 = ireduce.i8 v0      ; v1 = 0xEF (type I8)
```

### Float Conversions

**Integer ↔ Float:**
```
fcvt_from_uint  ; unsigned int → float
fcvt_from_sint  ; signed int → float
fcvt_to_uint    ; float → unsigned int (truncate)
fcvt_to_sint    ; float → signed int (truncate)
```

**Float ↔ Float:**
```
fpromote   ; F32 → F64 (widen)
fdemote    ; F64 → F32 (narrow, may lose precision)
```

**Example:**
```
v0 = iconst.i32 42
v1 = fcvt_from_sint.f32 v0   ; v1 = 42.0 (type F32)
v2 = fcvt_to_sint.i64 v1     ; v2 = 42 (type I64)
```

## Type Legalization

Some types aren't supported by hardware and must be legalized.

**File:** `/Users/joel/Work/hoist/src/codegen/legalize_types.zig`

### Legalization Actions

```zig
pub const LegalizeAction = enum {
    legal,         // Type is supported as-is
    promote,       // Widen to larger type
    expand,        // Split into multiple operations
    split_vector,  // Split vector into scalar operations
    widen_vector,  // Pad vector to supported size
};
```

### Example: I128 on 64-bit ARM64

```
Before legalization:
  v0 = iconst.i128 0x123456789ABCDEF0123456789ABCDEF
  v1 = iadd.i128 v0, v0

After legalization:
  v0_lo = iconst.i64 0x123456789ABCDEF
  v0_hi = iconst.i64 0x0123456789ABCDEF
  v1_lo = iadd.i64 v0_lo, v0_lo       ; Add low halves
  v1_carry = icmp_ult v1_lo, v0_lo    ; Detect carry
  v1_hi = iadd.i64 v0_hi, v0_hi       ; Add high halves
  v1_hi = iadd.i64 v1_hi, v1_carry    ; Add carry
```

## Type System Design Principles

### 1. Compact Representation

Each value stores its type inline (u16), not a pointer to a type object. This saves memory.

### 2. Explicit Types

IR operations explicitly specify result types:
```
v0 = iadd.i32 v1, v2    ; Type is I32 (explicit)
```

Not inferred from operands. This makes verification easier.

### 3. No Implicit Conversions

Must explicitly convert:
```
v0 = iconst.i32 42
v1 = sextend.i64 v0     ; MUST extend explicitly
v2 = iadd.i64 v1, v3    ; Now types match
```

### 4. Vector/Scalar Separation

Vectors and scalars are separate - no automatic broadcasting:
```
v0 = vconst.i32x4 [1,2,3,4]
v1 = iconst.i32 5
; Can't directly add - must splat scalar to vector first
v2 = vsplat.i32x4 v1        ; v2 = [5,5,5,5]
v3 = iadd.i32x4 v0, v2      ; Now OK
```

## Type Inference in Frontend

While IR requires explicit types, frontends can infer:

```zig
// Frontend code (hypothetical):
let x = 42;              // Infer I32 or I64
let y = 3.14;            // Infer F64
let z = x + y;           // Error: must convert

// Generated IR:
v0 = iconst.i32 42
v1 = fconst.f64 3.14
v2 = fcvt_from_sint.f64 v0    ; Convert x to F64
v3 = fadd.f64 v2, v1          ; Now can add
```

## Key Insights

1. **Types are values, not objects**: Compact u16 encoding

2. **Explicit over implicit**: No hidden conversions

3. **Vector ≠ Scalar**: Separate type hierarchy

4. **Legalization handles unsupported types**: I128 → pair of I64

5. **Types determine register allocation**: int vs float classes

6. **Verifier enforces type safety**: Catches errors early

Next: **08-atomics-and-memory.md** (concurrent memory operations)
