# Gap Closure Implementation Plan

Based on comprehensive Cranelift gap analysis (see `cranelift-gap-analysis.md`).

## Executive Summary

Hoist is **~91% feature-complete** compared to Cranelift for AArch64 JIT compilation.

### Current Status (2026-01-09)
- **IR Opcodes**: 100% (185/184 AArch64-relevant, 99.5% total with x86)
- **AArch64 Instructions**: 100%+ (more granular than Cranelift)
- **Optimization Passes**: 87.5% (14/16 capabilities)
- **ABI Features**: ~85% (classification 100%, lowering ~20%)

## Critical Gaps (Blocking Correctness)

### 1. Bitcast Opcode ⚠️ CRITICAL
**Priority**: P0 (HIGHEST)
**Effort**: Small (2-4 hours)
**Impact**: Cannot efficiently reinterpret float↔int without memory roundtrip

**Implementation**:
1. Add `Bitcast` to `src/ir/opcodes.zig`
2. Add ISLE lowering rule in `src/backends/aarch64/lower.isle`
3. Implement `aarch64_bitcast` in `src/backends/aarch64/isle_helpers.zig`
   - Use FMOV between scalar and vector registers
   - i32→f32: `fmov s0, w0`
   - f32→i32: `fmov w0, s0`
   - i64→f64: `fmov d0, x0`
   - f64→i64: `fmov x0, d0`

**Tracked**: `hoist-5ab67bb96889a3f2`

## High Priority Gaps (Significant Performance Impact)

### 2. Alias Analysis
**Priority**: P1
**Effort**: Large (2-3 weeks)
**Impact**: Enables redundant load elimination, load hoisting

**Implementation**:
1. Create `src/codegen/opts/alias.zig`
2. Implement points-to analysis
3. Integrate with GVN for redundant load elimination
4. Integrate with LICM for load hoisting

**Tracked**: `hoist-21c5bf62e04c6cd8`

## Medium Priority Gaps (Nice to Have)

### 3. Bmask Opcode
**Priority**: P2
**Effort**: Small (1-2 hours)
**Impact**: Improves SIMD select efficiency

**Implementation**:
1. Add `Bmask` to `src/ir/opcodes.zig`
2. Add lowering using CSETM or NEG
3. Add tests for i8/i16/i32/i64/i128

**Tracked**: `hoist-2646dc944ca3be68`

### 4. Multiple Calling Convention Support
**Priority**: P2
**Effort**: Medium (1-2 weeks)
**Impact**: Enables Windows ARM64 target

**Implementation**:
1. Extend `src/backends/aarch64/abi.zig`
2. Add Windows ARM64 calling convention
3. Add macOS ARM64 specifics (already mostly compatible)
4. Add calling convention selection infrastructure

### 5. Complex Aggregate ABI
**Priority**: P2
**Effort**: Medium (1-2 weeks)
**Impact**: Better C interop with large structs

**Implementation**:
1. Extend struct classification in `src/backends/aarch64/abi.zig`
2. Handle aggregates >16 bytes passed by reference
3. Handle NRAA (Natural Return Aggregate Address)
4. Add comprehensive tests

## Low Priority Gaps (Advanced Features)

### 6. E-graph Optimizations
**Priority**: P3
**Effort**: Large (4-6 weeks)
**Impact**: Advanced pattern matching, better optimization opportunities

**Implementation**:
1. Create e-graph infrastructure in `src/codegen/opts/egraph.zig`
2. Define e-class representation
3. Implement saturation-based rewriting
4. Add extraction (cost-based selection)

### 7. Value Range Analysis
**Priority**: P3
**Effort**: Medium (2-3 weeks)
**Impact**: Better constant propagation, bounds check elimination

**Implementation**:
1. Create `src/codegen/opts/range.zig`
2. Implement interval arithmetic
3. Integrate with SCCP for better constant propagation
4. Add bounds check elimination using range info

## Implementation Order

### Phase 1: Critical Fixes (Week 1)
1. ✅ Exception handling infrastructure (COMPLETE)
2. ✅ Bitcast opcode (COMPLETE - commit 95361326)
3. ✅ Bmask opcode (COMPLETE - commit 95361326)

### Phase 2: High-Impact Optimizations (Weeks 2-4)
4. ✅ Alias analysis (COMPLETE - commits 48b9cd18, 2391dad4)

### Phase 3: ABI Completeness (Weeks 5-8)
5. Multiple calling conventions
6. Complex aggregate handling

### Phase 4: Advanced Optimizations (Weeks 9-16)
7. E-graph optimizations
8. Value range analysis

## Non-Gaps (Architectural Differences)

These are NOT gaps, just different design choices:

1. **ISLE vs Manual Lowering**
   - Cranelift: Declarative ISLE (138K lines)
   - Hoist: Imperative Zig lowering (cleaner, more maintainable)
   - Both valid approaches

2. **Instruction Granularity**
   - Cranelift: Broad categories (AluRRR, FpuRR, etc.)
   - Hoist: Specific variants (add_rr, add_imm, add_shifted, etc.)
   - Hoist is MORE specific, not less complete

3. **Register Allocation**
   - Cranelift: regalloc2 (SSA-based with backtracking)
   - Hoist: Linear scan with spilling
   - Both produce correct code

## Areas Where Hoist Excels

1. **Granular instruction control** - More explicit than ISLE
2. **Modern ARM features** - PAC, BTI well integrated
3. **Comprehensive atomics** - Full LDADD/LDCLR/etc. support
4. **Clean Zig codebase** - More maintainable than Rust
5. **Extensive optimization infrastructure** - 11 passes, including GVN, LICM, SCCP

## Success Metrics

- ✅ IR opcode coverage: 97.3% → **100%** (185/184 AArch64-relevant, 99.5% total with x86)
- ✅ Optimization coverage: 80-90% → **87.5%** (14/16 capabilities, see missing-optimization-passes.md)
- ✅ ABI coverage: 70% → **~85%** (HFA/HVA classification complete, 8 calling conventions defined)
- 🎯 Overall: **85-90%** → **~91%** current (IR 100%, Opt 87.5%, ABI 85%)

## Research Phase Complete (2026-01-09)

All gap analysis and research tasks completed:

**Documentation Added:**
- [x86-simd-opcodes.md](./x86-simd-opcodes.md) - x86 opcodes marked N/A for AArch64
- [missing-optimization-passes.md](./missing-optimization-passes.md) - Cranelift e-graph vs Hoist passes
- [calling-conventions.md](./calling-conventions.md) - 8 calling conventions surveyed
- [aggregate-abi.md](./aggregate-abi.md) - Struct passing rules and status

**Findings:**
- IR opcodes: 100% complete for AArch64 (x86-specific opcodes N/A)
- Optimizations: 87.5% (missing Spectre mitigation, spaceship operator)
- ABI: Classification 100%, lowering ~20% (needs 4-5 weeks)
- 27 redundant dots closed (already implemented features)
- 23 dots remain for Phase 3-4 implementation

## References

- [cranelift-gap-analysis.md](./cranelift-gap-analysis.md) - Detailed gap analysis
- [feature_gap_analysis.md](./feature_gap_analysis.md) - Original feature assessment
- [exception-handling-abi.md](./exception-handling-abi.md) - Exception handling design
- [x86-simd-opcodes.md](./x86-simd-opcodes.md) - x86 opcode analysis
- [missing-optimization-passes.md](./missing-optimization-passes.md) - Optimization survey
- [calling-conventions.md](./calling-conventions.md) - Calling convention requirements
- [aggregate-abi.md](./aggregate-abi.md) - Struct passing ABI

## Quick Wins to 100% (Small Dots, 2026-01-09)

Created 22 new small dots (10-120 min each) to reach 100% parity:

### Optimization Quick Wins (→ 100%)
- `hoist-e11447c0286975d9` - Spaceship optimization (60-90 min) → 93.75%
- `hoist-083474a1bb5195bd` - Add spectre_fence opcode (20 min)
- `hoist-8ce061d72d19a1d4` - Lower to ISB (30 min)
- `hoist-6447f1f4f2feeed5` - Spectre mitigation pass (90-120 min)
- `hoist-3065f1a79a1d503e` - Test Spectre (45 min) → 100%
- `hoist-7902cacdd611026a` - Div→shift strength reduction (30 min)
- `hoist-010446361a203cb2` - Mul→shift strength reduction (20 min)

### Fast Calling Convention (→ 90% ABI)
- `hoist-17b7a86154f482ea` - Wire Fast to abi.fast() (30 min)
- `hoist-5ca5d3b539240a30` - Use ABI spec for marshaling (60 min)
- `hoist-31c3b289d9851782` - Test Fast callconv (60 min)

### PreserveAll Calling Convention (→ 92% ABI)
- `hoist-2c6dc8471e969c93` - Wire PreserveAll (15 min)
- `hoist-3613cc2a03a8f945` - Test PreserveAll spill (45 min)

### AppleAarch64 Calling Convention (→ 94% ABI)
- `hoist-48dcd732a29fd286` - Document Apple differences (90 min)
- `hoist-f0ef95c2b5342980` - Implement if different (30-60 min)

### Struct ABI (→ 96% ABI)
- `hoist-b4454fee46e6f00e` - Add struct_load/store opcodes (20 min)
- `hoist-8ec06747edd4a84c` - Lower HFA args (90 min)
- `hoist-6a7cb8cdc76a481a` - Lower HFA returns (90 min)
- `hoist-67c94cffa1792375` - Lower small struct args (90 min)
- `hoist-7bc99069c97b8dc8` - Add memcpy helper (60 min)
- `hoist-b14da1ae7ca8c359` - Lower large struct args (60 min)
- `hoist-3eba4f3d1fd718df` - Test HFA passing (45 min)

**Total effort for 100%:** ~18-22 hours (2-3 days focused work)
**Result:** IR 100%, Opt 100%, ABI 96% → **Overall ~98.7%**

## Dot Tracking (Legacy, Closed)

- ✅ `hoist-5ab67bb96889a3f2` - Implement bitcast opcode (COMPLETE)
- ✅ `hoist-2646dc944ca3be68` - Implement bmask opcode (COMPLETE)
- ✅ `hoist-21c5bf62e04c6cd8` - Implement alias analysis (COMPLETE)
