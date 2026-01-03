# Cranelift Compatibility Plan (ARM64 Backend)

This document tracks missing functionality for full Cranelift compatibility, assuming ARM64 backend only.

## CRITICAL Priority

### 1. Atomic Operations (5 opcodes)

**Missing Opcodes:**
- `atomic_load` - Load with memory ordering
- `atomic_store` - Store with memory ordering
- `atomic_rmw` - Atomic read-modify-write (add, sub, and, or, xor, xchg, etc.)
- `atomic_cas` - Compare-and-swap
- `fence` - Memory fence

**Files:**
- Add opcodes: `src/ir/opcodes.zig`
- Existing infrastructure: `src/ir/atomics.zig` (has AtomicOrdering, AtomicRmwOp)
- InstructionData: `src/ir/instruction_data.zig`
- ARM64 lowering: `src/codegen/aarch64/lower.zig`

**InstructionData Variants Needed:**
```zig
AtomicLoad { opcode, flags, addr, ordering }
AtomicStore { opcode, flags, addr, src, ordering }
AtomicRmw { opcode, flags, addr, src, op, ordering }
AtomicCas { opcode, flags, addr, expected, replacement, ordering }
Fence { opcode, ordering }
```

**ARM64 Lowering Strategy - Dual Path:**

ARM64 has TWO atomic implementation approaches:

1. **LSE (Large System Extensions)** - Modern single-instruction atomics:
   - `atomic_rmw(add)` → `LDADD`
   - `atomic_rmw(or)` → `LDSET`
   - `atomic_rmw(xor)` → `LDEOR`
   - `atomic_cas` → `CAS/CASP` (single/pair)
   - Requires: CPU feature detection or compile-time flag
   - Reference: Cranelift has ~97 LSE-related lowering rules

2. **LL/SC (Load-Link/Store-Conditional)** - Fallback for older hardware:
   - `atomic_rmw(op)` → Loop: `LDAXR + op + STLXR + branch if failed`
   - `atomic_cas` → Loop: `LDAXR + compare + STLXR + branch if failed`
   - More instructions but universally supported

**Memory Ordering → ARM64 Instruction Mapping:**
- `unordered` → Plain LDR/STR (no barriers, no atomicity guarantees)
- `monotonic` → Plain LDR/STR (atomic access, no ordering)
- `acquire` → LDAR/LDAPR (acquire load)
- `release` → STLR (release store)
- `acq_rel` → LDAXR/STLXR (acquire load + release store)
- `seq_cst` → DMB ISH + LDAR/STLR or LDAXR/STLXR (full barrier)

**Fence Instructions:**
- `fence(seq_cst)` → `DMB ISH` (Inner Shareable full barrier)
- `fence(acq_rel)` → `DMB ISH`
- `fence(release)` → `DMB ISHST` (store-only barrier)

**Action Items:**
1. Add atomic opcodes to Opcode enum
2. Create InstructionData variants with ordering fields
3. Implement dual-path ARM64 lowering:
   - Add CPU feature flag for LSE support
   - Implement LSE lowering (single instruction per atomic)
   - Implement LL/SC fallback (loop-based)
   - Add runtime or compile-time selection between paths
4. Add verifier rules:
   - Validate ordering values are legal
   - Validate atomic operations on valid types (integers only)
   - Validate alignment requirements (atomics require natural alignment)
5. Add comprehensive tests:
   - Each atomic operation (load, store, RMW ops, CAS)
   - Each memory ordering level
   - Both LSE and LL/SC code paths
   - Multi-threaded correctness tests (if possible)

**Dependencies:** None - infrastructure already exists

**Cranelift Reference:** `cranelift/codegen/src/isa/aarch64/lower/isle/generated_code.rs` (LSE lowering rules)

### 2. Type Conversion Operations (11 opcodes)

**Missing Opcodes:**

Integer conversions:
- `sextend` - Sign-extend to wider integer
- `uextend` - Zero-extend to wider integer
- `ireduce` - Truncate to narrower integer
- `iconcat` - Concatenate two integers into wider type
- `isplit` - Split integer into two narrower halves

Float conversions:
- `fcvt_from_sint` - Convert signed int to float
- `fcvt_from_uint` - Convert unsigned int to float
- `fcvt_to_sint` - Convert float to signed int (trap on overflow)
- `fcvt_to_sint_sat` - Convert float to signed int (saturate on overflow)
- `fcvt_to_uint` - Convert float to unsigned int (trap on overflow)
- `fcvt_to_uint_sat` - Convert float to unsigned int (saturate on overflow)

Float width conversions:
- `fpromote` - Widen float (f32 -> f64)
- `fdemote` - Narrow float (f64 -> f32)

**Files:**
- Add opcodes: `src/ir/opcodes.zig`
- InstructionData variants: `src/ir/instruction_data.zig`
- ARM64 lowering: `src/codegen/aarch64/lower.zig`

**Trap vs Saturate Semantics:**
- `fcvt_to_sint/uint` MUST TRAP on:
  - NaN inputs
  - Overflow (value exceeds target integer range)
  - Implementation: Insert bounds checks + conditional trap instructions
- `fcvt_to_sint_sat/uint_sat` MUST SATURATE:
  - NaN → 0
  - +Infinity → MAX_INT
  - -Infinity → MIN_INT (or 0 for unsigned)
  - ARM64: Use FCVTZS/FCVTZU with saturation variants

**Integer Concat/Split (I128 Support):**
- `iconcat(i64_lo, i64_hi) -> i128` - Concatenate two i64 into i128
- `isplit(i128) -> (i64_lo, i64_hi)` - Split i128 into two i64
- ARM64 lowering: Use register pairs (X0+X1 for i128)

**Vector Conversion Paths:**
- ARM64 NEON has specialized vector instructions
- `fcvt_from_sint` on vectors → SCVTF (vector form)
- Scalar and vector paths are different, document both

**Action Items:**
1. Add all conversion opcodes to Opcode enum
2. Create InstructionData variants:
   - Unary for most conversions (sextend, uextend, ireduce, fpromote, fdemote, fcvt_*)
   - Binary for iconcat (two inputs)
   - UnaryImm for isplit (returns two results)
3. Add ARM64 lowering:
   - Integer extend: SXTB/SXTH/SXTW (sign-extend), UXTB/UXTH/UXTW (zero-extend)
   - Integer reduce: Use low register portion (implicit truncation)
   - Integer concat/split: Register pair operations
   - Float conversion with traps: FCVTZS/FCVTZU + bounds check + trap
   - Float conversion with saturation: FCVTZS/FCVTZU with saturation mode
   - Float width: FCVT (f32↔f64)
   - Vector conversions: SCVTF/UCVTF (vector forms)
4. Add verifier rules:
   - Type compatibility (source → destination types valid)
   - Trap conversion only on potentially-overflow-prone sizes
   - Saturation conversion semantics documented
5. Add comprehensive tests:
   - Each conversion opcode with normal values
   - Trap conversions: NaN, +/-Infinity, overflow edge cases
   - Saturate conversions: NaN → 0, Infinity → MAX/MIN
   - iconcat/isplit: i64 pairs to i128 and back
   - Vector conversions: ensure vector form used

**Dependencies:** None

**Cranelift Reference:** `cranelift/codegen/src/isa/aarch64/lower.rs` (conversion lowering)

### 3. Alias Analysis Pass

**Description:**
Analyze memory dependencies to enable load elimination, store-to-load forwarding, dead store elimination, and instruction reordering. Determines whether two memory operations may access the same location (may-alias) or definitely access the same location (must-alias) or definitely access different locations (no-alias).

**Files:**
- NEW: `src/codegen/opts/alias_analysis.zig` (main analysis pass)
- NEW: `src/ir/memory_ssa.zig` (Memory SSA representation)
- Integration: `src/codegen/optimize.zig` (add to optimization pipeline)
- Extend: `src/ir/verifier.zig` (validate memory operation semantics)

**Alias Analysis Algorithm - Andersen-Style Points-To Analysis:**

Use a constraint-based points-to analysis suitable for compiler IL:

1. **Address-taken analysis**: Identify all values that represent memory addresses
2. **Constraint generation**: For each instruction, generate points-to constraints
3. **Constraint solving**: Iteratively solve constraints to fixed point
4. **Query interface**: Provide alias queries for optimization passes

**Data Structures:**

```zig
/// Represents a memory location or abstract location
const MemoryLocation = struct {
    /// Base pointer SSA value
    base: Value,

    /// Offset from base (if statically known)
    offset: ?i64,

    /// Size of access (if statically known)
    size: ?u64,

    /// Metadata: stack slot, heap allocation, global, etc.
    kind: LocationKind,
};

const LocationKind = enum {
    stack_slot,     // Stack-allocated local variable
    heap,           // Heap allocation (malloc, etc.)
    global,         // Global variable or constant
    argument,       // Function argument pointer
    unknown,        // Unknown origin (conservative)
};

/// Points-to set: maps each SSA value to set of possible memory locations
const PointsToSet = std.AutoHashMap(Value, std.AutoArrayHashMap(MemoryLocation, void));

/// Alias analysis result
const AliasResult = enum {
    no_alias,       // Definitely different locations
    may_alias,      // Possibly same location
    must_alias,     // Definitely same location
    partial_alias,  // Overlapping but not identical (e.g., struct.field vs struct)
};

pub const AliasAnalysis = struct {
    /// Points-to sets for all pointer values
    points_to: PointsToSet,

    /// Memory SSA representation (optional, for advanced optimizations)
    memory_ssa: ?MemorySSA,

    /// Call effects: which functions modify which memory
    call_effects: std.AutoHashMap(FunctionRef, MemoryEffects),

    /// Query: do two memory operations alias?
    pub fn alias(self: *const AliasAnalysis, loc1: MemoryLocation, loc2: MemoryLocation) AliasResult;

    /// Query: does a call modify a memory location?
    pub fn mayModify(self: *const AliasAnalysis, call: Value, loc: MemoryLocation) bool;
};
```

**Alias Query Algorithm:**

```zig
fn alias(loc1: MemoryLocation, loc2: MemoryLocation) AliasResult {
    // Fast path: identical locations
    if (loc1.base == loc2.base and loc1.offset == loc2.offset) {
        return .must_alias;
    }

    // Type-based aliasing (TBAA): different types don't alias
    if (typesCannotAlias(loc1.base.type, loc2.base.type)) {
        return .no_alias;
    }

    // Stack slot vs heap: never alias
    if (loc1.kind == .stack_slot and loc2.kind == .heap) return .no_alias;
    if (loc1.kind == .heap and loc2.kind == .stack_slot) return .no_alias;

    // Different stack slots: never alias
    if (loc1.kind == .stack_slot and loc2.kind == .stack_slot) {
        if (loc1.base != loc2.base) return .no_alias;
    }

    // Same base, different constant offsets: check overlap
    if (loc1.base == loc2.base and
        loc1.offset != null and loc2.offset != null and
        loc1.size != null and loc2.size != null) {

        const off1 = loc1.offset.?;
        const off2 = loc2.offset.?;
        const size1 = loc1.size.?;
        const size2 = loc2.size.?;

        // No overlap
        if (off1 + size1 <= off2 or off2 + size2 <= off1) {
            return .no_alias;
        }

        // Exact overlap
        if (off1 == off2 and size1 == size2) {
            return .must_alias;
        }

        // Partial overlap
        return .partial_alias;
    }

    // Conservative: may alias
    return .may_alias;
}
```

**Action Items:**

1. **Implement core alias analysis** in `src/codegen/opts/alias_analysis.zig`:
   - Define data structures (MemoryLocation, PointsToSet, AliasResult)
   - Implement constraint generation for each instruction type
   - Implement points-to analysis (iterative constraint solving)
   - Implement alias query interface

2. **Implement memory optimizations** (using alias analysis):
   - Redundant load elimination (NEW: `src/codegen/opts/rle.zig`)
   - Dead store elimination (NEW: `src/codegen/opts/dse.zig`)
   - Store-to-load forwarding (NEW: `src/codegen/opts/store_forward.zig`)

3. **Integrate with optimization pipeline** in `src/codegen/optimize.zig`:
   - Add alias analysis build step
   - Thread AliasAnalysis through optimization passes
   - Ensure alias analysis runs before dependent passes

4. **Add comprehensive tests**:
   - Stack slots vs heap: no alias
   - Different stack slots: no alias
   - Same stack slot, different offsets: check overlap
   - Load after store to same location → forward value
   - Load with intervening store to may-alias location → don't eliminate

**Dependencies:** None for Phase 1 (basic analysis)

**Cranelift Reference:** Cranelift uses simpler alias analysis (mostly stack vs heap)


## HIGH Priority

### 4. SIMD Vector Operations (13 opcodes)

**Missing Opcodes:**

Widening operations (split vector, widen lanes):
- `swiden_low` - Sign-extend low half of vector lanes
- `swiden_high` - Sign-extend high half of vector lanes
- `uwiden_low` - Zero-extend low half of vector lanes
- `uwiden_high` - Zero-extend high half of vector lanes

Narrowing operations (merge vector, narrow lanes):
- `snarrow` - Narrow signed with saturation
- `unarrow` - Narrow unsigned with saturation
- `uunarrow` - Narrow unsigned-to-unsigned with saturation

Lane manipulation:
- `scalar_to_vector` - Broadcast scalar to vector lanes
- `extract_vector` - Extract subvector (contiguous lanes)
- `iadd_pairwise` - Pairwise addition (adjacent lanes)

Float vector operations:
- `fvpromote_low` - Promote low half (f32x4 -> f64x2)
- `fvdemote` - Demote with saturation (f64x2 -> f32x4)

**Files:**
- Add opcodes: \`src/ir/opcodes.zig\`
- InstructionData: \`src/ir/instruction_data.zig\`
- ARM64 lowering: \`src/codegen/aarch64/lower.zig\`
- Vector types: \`src/ir/types.zig\` (already has vector support)

**Widening Operations - Precise Semantics:**

\`\`\`
swiden_low:  v8i8  [a0..a7] → v4i16 [sext(a0), sext(a1), sext(a2), sext(a3)]
swiden_high: v8i8  [a0..a7] → v4i16 [sext(a4), sext(a5), sext(a6), sext(a7)]
\`\`\`

**ARM64 Lowering for Widening:**
- \`swiden_low(v8i8 -> v8i16)\`: \`SXTL Vd.8H, Vn.8B\`
- \`swiden_high(v8i8 -> v8i16)\`: \`SXTL2 Vd.8H, Vn.16B\`
- \`uwiden_low(v4i16 -> v4i32)\`: \`UXTL Vd.4S, Vn.4H\`
- \`uwiden_high(v4i16 -> v4i32)\`: \`UXTL2 Vd.4S, Vn.8H\`

**Narrowing Operations - Precise Semantics:**

\`\`\`
snarrow: v4i32 [a0,a1,a2,a3], v4i32 [b0,b1,b2,b3] 
       → v8i16 [sat_s16(a0), sat_s16(a1), ..., sat_s16(b3)]
Saturation: value > i16::MAX (32767) → 32767
            value < i16::MIN (-32768) → -32768
\`\`\`

**ARM64 Lowering for Narrowing:**
- \`snarrow(v4i32, v4i32 -> v8i16)\`: \`SQXTN Vd.4H, Vn.4S\` + \`SQXTN2 Vd.8H, Vm.4S\`
- \`unarrow(v4i32, v4i32 -> v8i16)\`: \`SQXTUN Vd.4H, Vn.4S\` + \`SQXTUN2 Vd.8H, Vm.4S\`
- \`uunarrow(v4u32, v4u32 -> v8u16)\`: \`UQXTN Vd.4H, Vn.4S\` + \`UQXTN2 Vd.8H, Vm.4S\`

**Lane Manipulation:**
- \`scalar_to_vector(i32 -> v4i32)\`: \`DUP Vd.4S, Wn\`
- \`extract_vector(v4i32, lane=0 -> v2i32)\`: No-op (lower half)
- \`extract_vector(v4i32, lane=2 -> v2i32)\`: \`EXT Vd.16B, Vn.16B, Vn.16B, #8\`
- \`iadd_pairwise(v4i32 -> v2i32)\`: \`ADDP Vd.2S, Vn.4S\`

**Float Vector Operations:**
- \`fvpromote_low(v4f32 -> v2f64)\`: \`FCVTL Vd.2D, Vn.2S\`
- \`fvdemote(v2f64 -> v2f32)\`: \`FCVTN Vd.2S, Vn.2D\`

**Action Items:**

1. Add vector opcodes to Opcode enum
2. Create InstructionData variants (Unary for most, Binary for narrowing)
3. Implement ARM64 lowering with element size dispatch
4. Add verifier rules for lane count/width compatibility
5. Add comprehensive tests for all vector types and operations

**Dependencies:** Requires vector type support in \`src/ir/types.zig\` (already exists)


### 5. Division-by-Constant Optimization

**Description:** Replace expensive division/modulo by constants with multiply-shift sequences (magic numbers).

**Files:**
- NEW: `src/codegen/opts/div_const.zig`
- Integration: `src/codegen/optimize.zig`

**Action Items:**
1. Implement magic number generation:
   - Algorithm for computing magic multiplier and shift
   - Handle signed vs unsigned division
   - Handle power-of-2 special cases
2. Create DivConstOpt pass:
   - Pattern match div/mod by constant
   - Replace with multiply-shift sequence
   - Handle both 32-bit and 64-bit integers
3. Add to optimization pipeline (early pass)
4. Add tests for:
   - Various divisor values
   - Signed vs unsigned
   - Edge cases (div by 1, power of 2, etc.)

**Dependencies:** None

### 6. ISLE Optimization Rules

**Description:** Port pattern-matching optimization rules from Cranelift ISLE DSL.

**Cranelift Reference Files:**
- `cranelift/codegen/src/opts/arithmetic.isle` - Arithmetic identities
- `cranelift/codegen/src/opts/bitops.isle` - Bitwise operations
- `cranelift/codegen/src/opts/cprop.isle` - Constant propagation

**Target File:**
- Extend: `src/codegen/opts/instcombine.zig`

**Key Patterns to Port:**

Arithmetic:
- `x + 0 => x`, `x - 0 => x`, `x * 0 => 0`, `x * 1 => x`
- `x + (-x) => 0`, `x - x => 0`
- `(x + C1) + C2 => x + (C1 + C2)` (constant folding)
- `-(-x) => x`, `abs(abs(x)) => abs(x)`

Bitwise:
- `x & 0 => 0`, `x & -1 => x`, `x & x => x`
- `x | 0 => x`, `x | -1 => -1`, `x | x => x`
- `x ^ 0 => x`, `x ^ x => 0`
- De Morgan's laws: `~(x & y) => ~x | ~y`, `~(x | y) => ~x & ~y`
- Shift identities: `(x << C1) >> C1 => x` (if no overflow)

Constant propagation:
- Fold all operations with constant operands
- Propagate through conversions: `sextend(const) => const`
- Boolean simplification: `select(true, x, y) => x`

**Action Items:**
1. Study ISLE patterns in Cranelift source
2. Identify high-value patterns (most common in real code)
3. Implement pattern matching in instcombine.zig:
   - Add pattern structures
   - Add matching logic
   - Add replacement logic
4. Add comprehensive tests for each pattern
5. Benchmark impact on real-world code

**Dependencies:** None - extends existing instcombine pass

## MEDIUM Priority

### 7. Reference Types (for GC support)

**Description:** Support for garbage-collected references (WebAssembly GC, future languages).

**Files:**
- Extend: `src/ir/types.zig`
- Add InstructionData variants: `src/ir/instruction_data.zig`

**Action Items:**
1. Add reference type variants to Type enum:
   - `externref` - Opaque external reference
   - `funcref` - Function reference
   - Generic `ref` type with nullability
2. Add reference instructions if needed:
   - `ref.null`, `ref.is_null`, `ref.eq`
3. Update verifier for reference type rules
4. Add ARM64 lowering (references are just pointers on ARM64)
5. Add tests for reference types

**Dependencies:** None (but not needed until GC language support required)

### 8. Function Inlining

**Description:** Inline small functions at call sites for performance.

**Files:**
- NEW: `src/codegen/inline.zig`
- Integration: `src/codegen/optimize.zig`

**Action Items:**
1. Implement inlining heuristics:
   - Function size threshold
   - Call frequency analysis
   - Cost/benefit calculation
2. Implement IR cloning:
   - Clone function body
   - Remap SSA values
   - Fix up control flow
3. Create Inliner pass
4. Add to optimization pipeline
5. Add tests for:
   - Basic inlining
   - Recursive prevention
   - SSA value remapping
   - Control flow fixup

**Dependencies:** None

### 9. NaN Canonicalization (WebAssembly compliance)

**Description:** Ensure WebAssembly NaN determinism (canonical NaN representation).

**Files:**
- NEW: `src/codegen/opts/nan_canon.zig`
- Integration: `src/codegen/optimize.zig`

**Action Items:**
1. Implement NaN canonicalization pass:
   - Detect float operations that may produce NaN
   - Insert canonicalization after non-deterministic ops
2. Add ARM64 lowering for NaN canonicalization:
   - Use FABS/FNEG pattern or explicit checks
3. Add to optimization pipeline (late pass)
4. Add tests for WebAssembly NaN compliance

**Dependencies:** Only needed for WebAssembly target

### 10. Float Rounding Operations (4 opcodes)

**Missing Opcodes:**
- `ceil` - Round up to integer (as float)
- `floor` - Round down to integer (as float)
- `trunc` - Round toward zero (as float)
- `nearest` - Round to nearest even (as float)

**Files:**
- Add opcodes: `src/ir/opcodes.zig`
- InstructionData: `src/ir/instruction_data.zig` (Unary variant)
- ARM64 lowering: `src/codegen/aarch64/lower.zig`

**Action Items:**
1. Add rounding opcodes to Opcode enum
2. Use existing Unary InstructionData variant
3. Add ARM64 lowering using FRINTP/FRINTM/FRINTZ/FRINTN
4. Add verifier rules (float types only)
5. Add tests for each rounding mode

**Dependencies:** None

## LOWER Priority

### 11. Load/Store Variants (15 opcodes)

**Description:** Specialized load/store operations for narrow types and SIMD.

**Missing Opcodes:**

Scalar narrow loads (with extend):
- `sload8`, `uload8` - Load i8, extend to i32/i64
- `sload16`, `uload16` - Load i16, extend to i32/i64
- `sload32`, `uload32` - Load i32, extend to i64

Scalar narrow stores:
- `istore8` - Store low 8 bits
- `istore16` - Store low 16 bits
- `istore32` - Store low 32 bits

SIMD narrow loads (with lane widening):
- `sload8x8`, `uload8x8` - Load 8xi8, widen to 8xi16
- `sload16x4`, `uload16x4` - Load 4xi16, widen to 4xi32
- `sload32x2`, `uload32x2` - Load 2xi32, widen to 2xi64

**Files:**
- Add opcodes: `src/ir/opcodes.zig`
- InstructionData: `src/ir/instruction_data.zig`
- ARM64 lowering: `src/codegen/aarch64/lower.zig`

**Action Items:**
1. Add load/store opcodes
2. Create InstructionData variants (Load/Store with size and extend flags)
3. Add ARM64 lowering:
   - Scalar: LDRB/LDRH/LDR + SXTB/SXTH/SXTW or UXTB/UXTH
   - SIMD: LD1 + SSHLL/USHLL
4. Add verifier rules
5. Add tests

**Dependencies:** SIMD variants depend on vector type support

### 12. Type System Enhancements

**Missing Features:**

Vector type constructors:
- `Type.by(lanes)` - Create vector type with specified lane count
- `Type.vectorOf(scalar)` - Create vector from scalar type

Type splitting/merging:
- `Type.splitLanes()` - Split vector type into narrower lanes
- `Type.mergeLanes()` - Merge vector type into wider lanes

Dynamic SIMD vectors:
- Runtime-determined vector lengths (for SVE support)

**Files:**
- `src/ir/types.zig`

**Action Items:**
1. Add vector type constructor methods
2. Add lane manipulation methods
3. Add dynamic vector support (if SVE needed)
4. Update verifier for new type capabilities
5. Add tests

**Dependencies:** None for basic features; SVE requires ARM64 SVE support

### 13. Loop Analysis Enhancements

**Current State:** Basic loop detection exists in `src/ir/loops.zig`

**Missing Features:**
- Loop invariant code motion (LICM)
- Loop unrolling
- Loop strength reduction
- Loop peeling

**Files:**
- Extend: `src/ir/loops.zig`
- NEW: `src/codegen/opts/licm.zig`
- NEW: `src/codegen/opts/loop_unroll.zig`

**Action Items:**
1. Implement LICM pass:
   - Identify loop-invariant instructions
   - Safely hoist out of loop
2. Implement loop unrolling:
   - Unroll small fixed-trip-count loops
   - Partial unrolling for large loops
3. Add to optimization pipeline
4. Add tests

**Dependencies:** Requires alias analysis for safe LICM

## Out of Scope (Backend-Specific)

The following are NOT needed for ARM64-only target:

- x64 backend expansion
- RISC-V backend implementation
- s390x backend implementation
- Pulley interpreter backend
- x86-specific opcodes (x86_udivmodx, x86_sdivmodx, etc.)
- AVX/SSE-specific operations

## Implementation Priority Order

Recommended implementation order to maximize value:

1. **Type conversions** (CRITICAL) - Required for basic type system completeness
2. **Atomic operations** (CRITICAL) - Required for concurrent code
3. **Alias analysis** (CRITICAL) - Enables many other optimizations
4. **Division-by-constant** (HIGH) - High performance impact, self-contained
5. **ISLE optimization rules** (HIGH) - Broad performance impact
6. **SIMD vector operations** (HIGH) - Required for vectorized code
7. **Float rounding** (MEDIUM) - Simple to implement, needed for WebAssembly
8. **Function inlining** (MEDIUM) - High performance impact but complex
9. **Reference types** (MEDIUM) - Only needed for GC languages
10. **NaN canonicalization** (MEDIUM) - Only needed for WebAssembly
11. **Load/store variants** (LOW) - Can work around with explicit conversions
12. **Type system enhancements** (LOW) - Nice-to-have
13. **Loop analysis enhancements** (LOW) - Advanced optimizations

## Testing Strategy

For each feature:
1. Unit tests for core functionality
2. Integration tests with ARM64 lowering
3. Verification tests (IR validation)
4. End-to-end tests with real code patterns
5. Performance benchmarks where applicable

## Validation Criteria

Feature is complete when:
1. IR representation implemented
2. ARM64 lowering implemented
3. Verifier rules added
4. Tests passing (unit + integration)
5. Documented in relevant files
