# Missing Optimization Passes Analysis

**Date:** 2026-01-09
**Purpose:** Identify remaining Cranelift optimizations to reach 100% optimization coverage

## Executive Summary

**Current Status:**
- Hoist: 12 discrete optimization passes
- Cranelift: ISLE-based e-graph optimization (single unified pass)
- Coverage: ~85% (different architectural approach)

**Key Finding:** Cranelift and Hoist use fundamentally different optimization architectures:
- **Cranelift**: Single e-graph pass with ISLE pattern matching (all optimizations applied simultaneously)
- **Hoist**: Traditional pass manager with discrete optimization phases

**To reach 100% coverage:** Implement copy propagation pass (the only truly missing discrete pass)

---

## Cranelift Optimization Architecture

### Modern Approach (2024+)

Cranelift's optimization pipeline (from `src/context.rs:optimize()`):

```rust
pub fn optimize(&mut self, isa: &dyn TargetIsa) -> CodegenResult<()> {
    // 1. NaN canonicalization (optional)
    if isa.flags().enable_nan_canonicalization() {
        self.canonicalize_nans(isa)?;
    }

    // 2. Legalization
    self.legalize(isa)?;

    // 3. CFG and dominator tree
    self.compute_cfg();
    self.compute_domtree();

    // 4. Unreachable code elimination
    self.eliminate_unreachable_code(isa)?;

    // 5. Constant phi removal
    self.remove_constant_phis(isa)?;

    // 6. Resolve aliases
    self.func.dfg.resolve_all_aliases();

    // 7. E-graph optimization (if opt_level > 0)
    if opt_level != OptLevel::None {
        self.egraph_pass(isa, ctrl_plane)?;
    }

    Ok(())
}
```

**Key insight:** The `egraph_pass()` replaces what used to be 10+ discrete passes.

### E-graph Pass Contents (`src/opts/`)

The e-graph applies ISLE rewrite rules from:
1. **arithmetic.isle** (11KB) - Algebraic simplifications (add/sub/mul identities, strength reduction)
2. **bitops.isle** (8.5KB) - Bit manipulation (and/or/xor/not canonicalization)
3. **cprop.isle** (17KB) - Constant propagation and folding
4. **div_const.rs** (41KB) - Division by constant optimization
5. **extends.isle** (5KB) - Sign/zero extension elimination
6. **icmp.isle** (17KB) - Integer comparison simplification
7. **remat.isle** (1KB) - Rematerialization hints
8. **selects.isle** (6.5KB) - Select instruction optimization
9. **shifts.isle** (15KB) - Shift operation simplification
10. **skeleton.isle** (2KB) - Basic pattern infrastructure
11. **spaceship.isle** (8.3KB) - Comparison operator chaining
12. **spectre.isle** (0.7KB) - Spectre mitigation patterns
13. **vector.isle** (3.3KB) - SIMD vector optimizations

**Total:** ~115KB of ISLE optimization rules applied simultaneously via e-graph saturation.

---

## Hoist Optimization Architecture

### Traditional Pass Manager

Located in `src/codegen/opts/`, organized as discrete phases:

**IMPLEMENTED (12 PASSES):**

1. **Dead code elimination** (dce.zig, 6.8KB)
   - Removes unused instructions
   - Equivalent to post-e-graph DCE in Cranelift

2. **Global value numbering** (gvn.zig, 9.7KB)
   - Common subexpression elimination
   - Value deduplication
   - Equivalent to Cranelift's e-graph congruence

3. **Loop invariant code motion** (licm.zig, 10.9KB)
   - Hoists loop-invariant computations
   - No direct Cranelift equivalent (e-graph doesn't do code motion)

4. **Sparse conditional constant propagation** (sccp.zig, 29.5KB)
   - Data-flow constant propagation
   - More powerful than Cranelift's `cprop.isle`

5. **Instruction combining** (instcombine.zig, 114KB)
   - Algebraic simplifications
   - Pattern-based rewrites
   - Equivalent to combined arithmetic.isle + bitops.isle + extends.isle + shifts.isle

6. **Peephole optimizations** (peephole.zig, 21.8KB)
   - Local pattern matching
   - Equivalent to Cranelift's skeleton.isle + remat.isle

7. **Copy propagation** (copyprop.zig, 5.1KB)
   - Eliminates unnecessary copies
   - Equivalent to Cranelift's value aliasing + e-graph congruence

8. **Division by constant** (div_const.zig, 13.6KB)
   - Strength reduction for divisions
   - Direct equivalent to Cranelift's div_const.rs

9. **Strength reduction** (strength.zig, 20.1KB)
   - Mul→shift, div→mul optimizations
   - Equivalent to Cranelift's arithmetic.isle strength reduction

10. **Branch simplification** (simplifybranch.zig, 5.5KB)
    - Constant branch folding
    - Equivalent to Cranelift's icmp.isle + selects.isle

11. **Unreachable code elimination** (unreachable.zig, 5.8KB)
    - Removes unreachable blocks
    - Direct equivalent to Cranelift's eliminate_unreachable_code()

12. **Alias analysis** (alias.zig, 20.6KB) ✅ NEW
    - Points-to analysis
    - Redundant load elimination
    - Store-to-load forwarding
    - No direct Cranelift equivalent

**Total:** ~263KB of optimization code (2.3× more than Cranelift's ISLE rules)

---

## Gap Analysis

### What Cranelift Has That Hoist Lacks

**1. E-graph Infrastructure**
- **Cranelift:** Unified e-graph with automatic saturation
- **Hoist:** Fixed-order pass pipeline
- **Impact:** Cranelift can discover optimization sequences that require multiple passes in Hoist
- **Effort:** Large (4-6 weeks to implement e-graph)

**2. ISLE Pattern Matching**
- **Cranelift:** Declarative rewrite rules
- **Hoist:** Imperative Zig code
- **Impact:** ISLE rules are more composable, easier to verify
- **Effort:** N/A (architectural choice, both valid)

**3. Spaceship Operator Optimization**
- **Cranelift:** Specialized rules for comparison chains (spaceship.isle)
- **Hoist:** Not implemented
- **Impact:** Minor (rare pattern)
- **Effort:** Small (1-2 hours)

**4. Spectre Mitigation Patterns**
- **Cranelift:** Speculative execution barrier insertion (spectre.isle)
- **Hoist:** Not implemented
- **Impact:** Security-critical for JIT engines
- **Effort:** Small (2-3 hours)

### What Hoist Has That Cranelift Lacks

**1. Loop Invariant Code Motion**
- **Hoist:** Full LICM pass with hoisting analysis
- **Cranelift:** E-graph doesn't move code across blocks
- **Impact:** Better performance for loop-heavy code

**2. Sparse Conditional Constant Propagation**
- **Hoist:** Interprocedural constant propagation
- **Cranelift:** Local constant folding only
- **Impact:** More aggressive constant propagation

**3. Alias Analysis**
- **Hoist:** Full points-to analysis with memory SSA
- **Cranelift:** Conservative memory ordering
- **Impact:** Better memory optimization (loads, stores)

**4. Standalone Peephole Pass**
- **Hoist:** Dedicated local optimization phase
- **Cranelift:** Integrated into e-graph
- **Impact:** More control over optimization order

---

## Coverage Calculation

### Discrete Optimization Capabilities

| Capability | Cranelift | Hoist | Status |
|------------|-----------|-------|--------|
| Constant propagation | ✅ cprop.isle | ✅ sccp.zig | EQUIVALENT |
| Common subexpression elimination | ✅ e-graph | ✅ gvn.zig | EQUIVALENT |
| Dead code elimination | ✅ implicit | ✅ dce.zig | EQUIVALENT |
| Algebraic simplification | ✅ arithmetic.isle | ✅ instcombine.zig | EQUIVALENT |
| Bit manipulation | ✅ bitops.isle | ✅ instcombine.zig | EQUIVALENT |
| Division optimization | ✅ div_const.rs | ✅ div_const.zig | EQUIVALENT |
| Strength reduction | ✅ arithmetic.isle | ✅ strength.zig | EQUIVALENT |
| Comparison simplification | ✅ icmp.isle | ✅ simplifybranch.zig | EQUIVALENT |
| Select optimization | ✅ selects.isle | ✅ instcombine.zig | EQUIVALENT |
| Extension elimination | ✅ extends.isle | ✅ instcombine.zig | EQUIVALENT |
| Shift optimization | ✅ shifts.isle | ✅ instcombine.zig | EQUIVALENT |
| Unreachable elimination | ✅ explicit | ✅ unreachable.zig | EQUIVALENT |
| Phi simplification | ✅ remove_constant_phis | ✅ implicit in SCCP | EQUIVALENT |
| Copy propagation | ✅ alias resolution | ✅ copyprop.zig | EQUIVALENT |
| Loop invariant code motion | ❌ | ✅ licm.zig | HOIST ONLY |
| Alias analysis | ❌ | ✅ alias.zig | HOIST ONLY |
| Spaceship optimization | ✅ spaceship.isle | ❌ | CRANELIFT ONLY |
| Spectre mitigation | ✅ spectre.isle | ❌ | CRANELIFT ONLY |

**Cranelift capabilities:** 16 (14 common + 2 exclusive)
**Hoist capabilities:** 16 (14 common + 2 exclusive)
**Coverage:** 14/16 common = 87.5%

---

## Recommendations for 100% Coverage

### Priority 1: Spectre Mitigation (Security)

**Effort:** Small (2-3 hours)
**Impact:** Security-critical for sandboxing
**Implementation:**
1. Add `SpectreFence` opcode to IR
2. Insert barriers after bounds checks
3. Lower to platform-specific instructions:
   - AArch64: `DSB SY` or `ISB`
   - x86: `LFENCE`

**Files:**
- `src/ir/opcodes.zig` - add `spectre_fence` opcode
- `src/backends/aarch64/lower.isle` - lower to DSB/ISB
- `src/codegen/opts/spectre.zig` - fence insertion pass

### Priority 2: Spaceship Optimization (Completeness)

**Effort:** Small (1-2 hours)
**Impact:** Minor (rare pattern)
**Implementation:**
1. Detect comparison chains: `(a < b) ? -1 : (a > b) ? 1 : 0`
2. Replace with single `cmp` + conditional moves
3. AArch64: Use `CSEL` / `CSINC` / `CSINV`

**Files:**
- `src/codegen/opts/instcombine.zig` - add spaceship pattern matching

### Priority 3: E-graph Infrastructure (Future)

**Effort:** Large (4-6 weeks)
**Impact:** Enables more optimization opportunities
**Implementation:**
- See Phase 4 in gap-closure-plan.md
- Would unify many existing passes
- Trade-off: More complex, but potentially faster

---

## Updated Metrics

**Current:**
- Hoist optimization passes: 12
- Cranelift capabilities: 16
- Coverage: 14/16 = 87.5%

**After Spectre + Spaceship:**
- Hoist optimization passes: 14
- Cranelift capabilities: 16
- Coverage: 16/16 = **100%**

**After E-graph (future):**
- Hoist would have unified e-graph + LICM + alias analysis
- Would exceed Cranelift's optimization power

---

## References

- Cranelift source: `~/Work/wasmtime/cranelift/codegen/src/`
- Cranelift opts: `~/Work/wasmtime/cranelift/codegen/src/opts/`
- Hoist opts: `src/codegen/opts/`
- E-graph paper: "Equality Saturation: A New Approach to Optimization" (POPL 2009)
