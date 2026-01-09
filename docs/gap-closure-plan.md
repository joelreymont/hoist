# Gap Closure Implementation Plan

Based on comprehensive Cranelift gap analysis (see `cranelift-gap-analysis.md`).

## Executive Summary

Hoist is **85-90% feature-complete** compared to Cranelift for AArch64 JIT compilation.

### Current Status
- **IR Opcodes**: 97.3% (181/186)
- **AArch64 Instructions**: 100%+ (more granular than Cranelift)
- **Optimization Passes**: 80-90% (11/14)
- **ABI Features**: ~70%

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

- ✅ IR opcode coverage: 97.3% → **99.5%** (184/186 - bitcast + bmask complete)
- ✅ Optimization coverage: 80-90% → **~92%** (12 passes including alias analysis)
- ⚠️ ABI coverage: 70% → **90%** (add calling conventions + aggregates)
- 🎯 Overall: **85-90%** → **~90%** current, **95%+** with ABI work

## References

- [cranelift-gap-analysis.md](./cranelift-gap-analysis.md) - Detailed gap analysis
- [feature_gap_analysis.md](./feature_gap_analysis.md) - Original feature assessment
- [exception-handling-abi.md](./exception-handling-abi.md) - Exception handling design

## Dot Tracking

- `hoist-5ab67bb96889a3f2` - Implement bitcast opcode (CRITICAL)
- `hoist-2646dc944ca3be68` - Implement bmask opcode (MEDIUM)
- `hoist-21c5bf62e04c6cd8` - Implement alias analysis (HIGH)
