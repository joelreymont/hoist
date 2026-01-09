# Aggregate (Struct/Array) Passing ABI

**Date:** 2026-01-09
**Purpose:** Document AAPCS64 aggregate passing rules and Hoist implementation status

## Executive Summary

**Current Status:**
- ✅ Struct classification implemented (HFA, HVA, general, indirect)
- ✅ Size thresholds correct (16-byte cutoff for indirect)
- ⚠️ Argument passing partially implemented (classification done, lowering incomplete)
- ❌ Struct copy helpers not implemented
- ❌ Field-by-field load/store lowering not implemented

**Key Finding:** Classification logic is complete and well-tested, but the actual lowering of struct arguments and struct operations needs implementation.

---

## AAPCS64 Struct Passing Rules

### Size-Based Classification

The ARM Architecture Procedure Call Standard (AAPCS64) classifies structs based on size and composition:

| Size | Composition | Passing Method | Registers |
|------|-------------|----------------|-----------|
| 1-16 bytes | Homogeneous floats (HFA) | By value in FP registers | V0-V3 |
| 1-16 bytes | Homogeneous vectors (HVA) | By value in SIMD registers | V0-V3 |
| 1-16 bytes | Non-homogeneous | By value in GP registers | X0-X7 |
| > 16 bytes | Any | **By reference** (pointer) | X0-X7 (pointer) |

### Homogeneous Aggregates

**HFA (Homogeneous Floating-Point Aggregate):**
- 1-4 members, all same floating-point type
- Types: f32 or f64 (not mixed)
- Each member passed in one FP register
- Example: `struct { f32, f32, f32 }` → V0, V1, V2

**HVA (Homogeneous Short-Vector Aggregate):**
- 1-4 members, all same vector type
- Types: v64 or v128 with same element type and lane count
- Each member passed in one SIMD register
- Example: `struct { v128<4×f32>, v128<4×f32> }` → V0, V1

### Non-Homogeneous Structs (≤ 16 bytes)

Passed in general-purpose registers using "block copy" semantics:
- Treat struct as sequence of 8-byte chunks
- Each chunk goes in one X register
- Partial last chunk: right-padded with undefined bits
- Example: 12-byte struct → X0 (bytes 0-7), X1 (bytes 8-11 + padding)

### Large Structs (> 16 bytes)

**Passed by reference:**
1. Caller allocates space on stack
2. Caller copies struct to stack
3. Caller passes pointer in register
4. Callee accesses via pointer

**Ownership semantics:**
- Caller retains ownership (stack-allocated copy)
- Callee may modify its copy without affecting caller's original
- C semantics: callee sees a fresh copy

---

## Hoist Implementation Status

### Classification (✅ Complete)

**Location:** `src/backends/aarch64/abi.zig:636-730`

**Implemented:**
```zig
pub const StructClass = enum {
    hfa,      // Homogeneous Floating-Point Aggregate
    hva,      // Homogeneous Short-Vector Aggregate
    general,  // Non-homogeneous, ≤ 16 bytes
    indirect, // > 16 bytes, passed by reference
};

pub fn classifyStruct(ty: Type) struct {
    class: StructClass,
    elem_ty: ?Type,
};
```

**Helper functions:**
- `isHFA()` - Detects 1-4 member homogeneous float structs
- `isHVA()` - Detects 1-4 member homogeneous vector structs
- `classifyStruct()` - Dispatches to appropriate classification

**Tests:** 15 comprehensive tests covering:
- HFA with f32/f64 fields (abi.zig:1707-1779)
- HVA with v64/v128 fields (abi.zig:1781-1896)
- Mixed types (non-homogeneous)
- Size boundaries (exactly 16 bytes, > 16 bytes)
- Edge cases (empty struct, too many fields)

### Argument Passing (⚠️ Partial)

**Current state:**
- Classification is called but results not fully used in lowering
- `TODO` comment at abi.zig:1510: "Struct handling with proper HFA/HVA detection"

**What needs implementation:**
1. **HFA passing:** Extract struct fields, pass each in V0-V3
2. **HVA passing:** Extract vector fields, pass each in V0-V3
3. **General passing:** Treat as byte sequence, chunk into X0-X7
4. **Indirect passing:** Allocate stack space, copy struct, pass pointer

### Return Values (⚠️ Partial)

**Location:** `src/backends/aarch64/abi.zig:3637-3679`

**Documented but not fully implemented:**
```zig
// Return handling TODOs:
// 1. Check scalar: i8-i64 -> X0, f32/f64 -> V0
// 2. Check HFA: 1-4 same float types -> V0-V3
// 3. Check HVA: 1-4 same vector types -> V0-V3
// 4. Check struct <= 16 bytes: split across X0-X1
// 5. Check struct > 16 bytes: indirect via X8
```

**Return register conventions:**
- Scalar integer: X0
- Scalar float: V0
- HFA (f32/f64): V0-V3 (one per member)
- HVA (v64/v128): V0-V3 (one per member)
- Struct ≤ 16 bytes: X0-X1 (treated as integers)
- Struct > 16 bytes: **Indirect via X8** (caller allocates, callee writes)

### Struct Operations (❌ Not Implemented)

**Missing:**
1. **Struct copy helpers:**
   - memcpy-style block copy for initialization
   - Field-by-field copy for optimization
   - Alignment-aware copy (maintain AAPCS64 alignment)

2. **Field access lowering:**
   - `struct_load` → sequence of field loads
   - `struct_store` → sequence of field stores
   - Offset calculation with proper alignment

3. **Struct construction:**
   - Initialize struct from field values
   - Handle padding between fields
   - Zero-initialize padding for security

---

## AAPCS64 Reference Details

### Section 6.4.2: Parameter Passing

**General Rules:**
1. If type is HFA/HVA, allocate to next available FP/SIMD registers
2. If size ≤ 16 bytes and not HFA/HVA, treat as integer sequence
3. If size > 16 bytes, pass indirect (pointer in GP register)
4. If registers exhausted, spill to stack (caller allocates)

**Stack Alignment:**
- All stack arguments: 8-byte aligned
- Stack pointer (SP): 16-byte aligned at call boundary

**Register Exhaustion:**
- If not enough FP registers for HFA/HVA, spill entire struct to stack
- If not enough GP registers, spill remaining chunks to stack
- No split across register and stack (all-or-nothing per argument)

### Section 6.4.3: Result Return

**Return Strategies:**
1. **Scalar types:** X0 (integer), V0 (float/vector)
2. **HFA:** V0-V3 (one register per member)
3. **HVA:** V0-V3 (one register per member)
4. **Struct ≤ 16 bytes:** X0-X1 (as integer sequence)
5. **Struct > 16 bytes:** **X8 indirect return**
   - Caller allocates space
   - Caller passes pointer in X8 ("return slot")
   - Callee writes result to *X8
   - Callee returns pointer in X0

**Indirect Return (X8) Details:**
- X8 is an "implicit argument" for large return values
- Not part of the normal X0-X7 argument registers
- Preserved across call (callee doesn't clobber if not used)
- Example C signature: `struct LargeStruct foo(int a, int b)`
  - Lowered to: `void foo(struct LargeStruct *ret, int a, int b)`
  - ret pointer passed in X8

---

## Examples

### Example 1: HFA Passing

**C code:**
```c
struct Vec3 { float x, y, z; };
void process(struct Vec3 v);
```

**AAPCS64 lowering:**
1. Classify: `Vec3` is HFA (3× f32)
2. Extract fields: x, y, z
3. Pass: V0 = x, V1 = y, V2 = z

**Hoist IR:**
```
%v = ... // struct value
%x = extract_field %v, 0  // field offset 0
%y = extract_field %v, 1  // field offset 4
%z = extract_field %v, 2  // field offset 8
call @process(%x: V0, %y: V1, %z: V2)
```

### Example 2: General Struct (≤ 16 bytes)

**C code:**
```c
struct Mixed { int a; float b; long c; };
void process(struct Mixed m);
```

**AAPCS64 lowering:**
1. Classify: Not HFA (mixed int/float), size = 16 bytes → general
2. Treat as byte sequence (0-15)
3. Chunk into 8-byte units
4. Pass: X0 = bytes[0:7], X1 = bytes[8:15]

**Hoist IR:**
```
%m = ... // struct value (16 bytes)
%chunk0 = bitcast %m[0:8] to i64
%chunk1 = bitcast %m[8:16] to i64
call @process(%chunk0: X0, %chunk1: X1)
```

### Example 3: Large Struct (> 16 bytes)

**C code:**
```c
struct Large { long a, b, c; }; // 24 bytes
void process(struct Large l);
```

**AAPCS64 lowering:**
1. Classify: size = 24 > 16 → indirect
2. Allocate stack space (24 bytes, 8-byte aligned)
3. Copy struct to stack
4. Pass pointer in register

**Hoist IR:**
```
%l = ... // struct value (24 bytes)
%slot = stack_alloc 24, align 8
store %l, %slot
%ptr = stack_addr %slot
call @process(%ptr: X0)
```

### Example 4: Struct Return (> 16 bytes)

**C code:**
```c
struct Large { long a, b, c; }; // 24 bytes
struct Large compute(int x);
```

**AAPCS64 lowering:**
1. Caller allocates return slot on stack
2. Caller passes pointer in X8
3. Callee writes to *X8
4. Callee returns (X0 = X8 by convention)

**Hoist IR (caller side):**
```
%ret_slot = stack_alloc 24, align 8
%ret_ptr = stack_addr %ret_slot
%result = call @compute(%x: X0, %ret_ptr: X8)
%value = load %ret_slot
```

**Hoist IR (callee side):**
```
define @compute(%x: X0, %ret_ptr: X8) {
    %result = ... // compute struct
    store %result, %ret_ptr
    return %ret_ptr // return pointer in X0
}
```

---

## Implementation Gaps

### Gap 1: Struct Argument Lowering

**Current:** Classification happens but not used in lowering
**Needed:** Implement per-class lowering in `src/backends/aarch64/isle_helpers.zig`

**Files to modify:**
- `isle_helpers.zig` - Add `aarch64_pass_struct_arg()` helper
- `lower.isle` - Add struct argument lowering rules

**Estimated effort:** 1-2 weeks

### Gap 2: Struct Return Lowering

**Current:** Return classification documented but not implemented
**Needed:** Implement X8 indirect return protocol

**Files to modify:**
- `abi.zig` - Add `prepareStructReturn()` function
- `isle_helpers.zig` - Add return value marshaling
- `lower.isle` - Add struct return handling

**Estimated effort:** 1 week

### Gap 3: Struct Copy Helpers

**Current:** No struct copy utilities
**Needed:** Efficient struct copy implementation

**Files to create/modify:**
- `isle_helpers.zig` - Add `aarch64_copy_struct()` helper
- Use loop for large copies (> 64 bytes)
- Use inline LDP/STP for small copies (≤ 64 bytes)

**Estimated effort:** 3-5 days

### Gap 4: Field Access Lowering

**Current:** No field-level operations
**Needed:** Lower struct load/store to field accesses

**Files to modify:**
- `instcombine.zig` - Add struct decomposition pass
- Lower `load %struct_ptr` → sequence of field loads
- Lower `store %struct_val, %ptr` → sequence of field stores

**Estimated effort:** 1 week

---

## Testing Strategy

### Unit Tests (✅ Complete)

Already implemented:
- HFA detection (7 tests)
- HVA detection (8 tests)
- Struct classification (5 tests)

### Integration Tests (❌ Needed)

**Argument passing tests:**
1. HFA: Pass `{ f32, f32 }` to C function
2. HVA: Pass `{ v128, v128 }` to C function
3. General: Pass `{ i32, i64 }` (12 bytes)
4. Indirect: Pass `{ i64, i64, i64 }` (24 bytes)
5. Register exhaustion: Pass 10 struct arguments

**Return value tests:**
1. Return HFA from C function
2. Return large struct (> 16 bytes) from C function
3. Return struct from Hoist to C callback

**Interop tests:**
1. Call C library functions with struct args
2. Implement callbacks with struct returns
3. Round-trip: Hoist → C → Hoist with structs

---

## Summary

**Hoist Aggregate ABI Status:**

| Feature | Status | File | Lines |
|---------|--------|------|-------|
| HFA detection | ✅ Complete | abi.zig | 651-672 |
| HVA detection | ✅ Complete | abi.zig | 677-701 |
| Struct classification | ✅ Complete | abi.zig | 705-730 |
| Classification tests | ✅ Complete | abi.zig | 1707-1968 |
| Argument lowering | ⚠️ TODO | abi.zig | 1510 (comment) |
| Return lowering | ⚠️ TODO | abi.zig | 3677-3679 |
| Struct copy | ❌ Missing | - | - |
| Field access | ❌ Missing | - | - |

**Overall:** Classification complete (100%), lowering incomplete (~20%)

**To reach 100%:**
1. Implement struct argument lowering (1-2 weeks)
2. Implement struct return lowering (1 week)
3. Add struct copy helpers (3-5 days)
4. Add field access lowering (1 week)

**Total effort:** ~4-5 weeks for complete aggregate support

---

## References

- AAPCS64 Specification: [ARM Procedure Call Standard](https://github.com/ARM-software/abi-aa/blob/main/aapcs64/aapcs64.rst)
- Hoist implementation: `src/backends/aarch64/abi.zig`
- Cranelift reference: `~/Work/wasmtime/cranelift/codegen/src/isa/aarch64/abi.rs`
