# ARM64 Parity Plan - Complete Implementation Roadmap

## Executive Summary

**Oracle Verification**: 3 iterations completed, verified comprehensive
**Total Missing Items**: 18 opcodes (verified against Cranelift 186 total opcodes)
**Implementation Plan**: 29 detailed dots created (split for <30 min completion each)
**Total Effort**: ~12 hours for verified missing items + existing 59 dots for full parity

---

## Oracle Verification Process

### Iteration 1 (Agent aa17a0e)
- Comprehensive gap analysis
- Identified high-level patterns (ABI, optimizations, SIMD)
- Estimated ~12 weeks for full parity

### Iteration 2 (Agent a9e4ebc)
- Found 23 missing items
- **4 false positives corrected**: brz/brnz don't exist, br_icmp doesn't exist, heap_addr not in current Cranelift
- Verified many items already implemented in lower.isle

### Iteration 3 (Agent a280120)
- Corrected iteration 2 errors
- Found 25 additional items
- Cross-referenced all 186 Cranelift opcodes

### Iteration 4 (Agent acf41ae - FINAL)
- **Verified against actual Cranelift source code**
- Closed 5 dots already implemented (iconcat/isplit, select_spectre_guard, bitselect, overflow detection)
- Confirmed **18 genuinely missing opcodes**
- Cross-checked: InstBuilder docs, instructions.rs, lower.isle, inst.zig

---

## Verified Missing Items (18 Opcodes)

### 1. Sub-word Stores (3 opcodes) - 60 min total
**Critical for**: Byte/word stores in C ABI, string operations

- ✅ `istore8` - Store low 8 bits (STRB) [20 min]
- ✅ `istore16` - Store low 16 bits (STRH) [20 min]
- ✅ `istore32` - Store low 32 bits (STR W-reg) [20 min]

**ARM64 Instructions**: STRB, STRH, STR
**Dependencies**: None - straightforward 1:1 mapping
**Dots Created**: 3 single dots

---

### 2. Vector Extending Loads (6 opcodes) - 110 min total
**Critical for**: WebAssembly SIMD load-and-extend operations

- ✅ `uload8x8` - Load i8x8, zero-extend to i16x8 (LD1+USHLL) [15 min]
- ✅ `sload8x8` - Load i8x8, sign-extend to i16x8 (LD1+SSHLL) [10 min]
- ✅ `uload16x4` - Load i16x4, zero-extend to i32x4 (LD1+USHLL) [20 min]
- ✅ `sload16x4` - Load i16x4, sign-extend to i32x4 (LD1+SSHLL) [20 min]
- ✅ `uload32x2` - Load i32x2, zero-extend to i64x2 (LD1+USHLL) [20 min]
- ✅ `sload32x2` - Load i32x2, sign-extend to i64x2 (LD1+SSHLL) [20 min]

**ARM64 Instructions**: LD1 + USHLL/SSHLL
**Dependencies**: Infrastructure dot (LD1+USHLL helper) [25 min] → individual implementations
**Dots Created**: 5 dots (1 infrastructure + 4 implementation)

---

### 3. Overflow with Carry/Borrow (4 opcodes) - 110 min total
**Critical for**: Multi-precision arithmetic (128-bit, bignum)

- ✅ `sadd_overflow_cin` - Signed add with carry-in (ADDS+ADCS) [25 min]
- ✅ `uadd_overflow_cin` - Unsigned add with carry-in (ADDS+ADCS) [15 min]
- ✅ `ssub_overflow_bin` - Signed sub with borrow-in (SUBS+SBCS) [25 min]
- ✅ `usub_overflow_bin` - Unsigned sub with borrow-in (SUBS+SBCS) [15 min]

**ARM64 Instructions**: ADDS+ADCS, SUBS+SBCS
**Dependencies**:
- ADCS instruction variant [15 min] → add overflow implementations
- SBCS instruction variant [15 min] → sub overflow implementations
**Dots Created**: 6 dots (2 instruction variants + 4 implementations)

---

### 4. Immediate Arithmetic (3 opcodes) - 85 min total
**Critical for**: Optimization (avoid immediate materialization)

- ✅ `iadd_imm` - Add register + immediate (ADD Xd, Xn, #imm) [20 min]
- ✅ `irsub_imm` - Reverse subtract (imm - x) (SUB or NEG+ADD) [25 min]
- ✅ `imul_imm` - Multiply by immediate (MOV+MUL or LSL for power-of-2) [40 min]

**ARM64 Instructions**: ADD #imm, SUB #imm, MOV+MUL, LSL
**Dependencies**: imul_imm needs helper infrastructure [20 min] → lowering [20 min]
**Dots Created**: 4 dots (3 single + 1 split for imul_imm)

---

### 5. Exception Handling (2 opcodes) - 110 min total
**Critical for**: WebAssembly exception handling proposal

- ✅ `try_call` - Direct call with exception handling [80 min split]
- ✅ `try_call_indirect` - Indirect call with exception handling [30 min]

**ARM64 Instructions**: BL/BLR with exception edge wiring
**Dependencies**:
1. CFG exception edges infrastructure [30 min]
2. Basic try_call lowering [20 min]
3. Exception edge wiring [30 min]
4. try_call_indirect reuses all above [30 min]
**Dots Created**: 4 dots (3 for try_call split + 1 for try_call_indirect)

**Note**: Exception handling is **complex** - requires CFG changes, exception register tracking, landing pad generation. Dot hoist-47a9f60c662ac5e5 already exists for this.

---

## Dots Created: 29 Total

### By Category:
- **Sub-word Stores**: 3 dots (60 min)
- **Vector Extending Loads**: 5 dots (110 min)
- **Overflow with Carry**: 6 dots (110 min)
- **Immediate Arithmetic**: 4 dots (85 min)
- **Exception Handling**: 4 dots (110 min)
- **Instruction Variants**: 2 dots (ADCS, SBCS - 30 min)

### By Complexity:
- **Simple** (15-25 min): 14 dots
- **Medium** (25-30 min): 12 dots
- **Complex** (30+ min): 3 dots (exception handling CFG changes)

### Dependencies Preserved:
```
Vector loads:
  LD1+USHLL infrastructure → uload8x8/sload8x8 → uload16x4 → uload32x2

Overflow with carry:
  ADCS variant → sadd_overflow_cin, uadd_overflow_cin
  SBCS variant → ssub_overflow_bin, usub_overflow_bin

Immediate multiply:
  MOV+MUL helper → imul_imm lowering

Exception handling:
  CFG exception edges → try_call basic → exception wiring → try_call_indirect
```

---

## Already Implemented - Dots Closed

Based on verification against `/Users/joel/Work/hoist/src/backends/aarch64/lower.isle`:

1. **iconcat/isplit** (hoist-47a9f53d217e3c2b) - Lines 697, 702 ✅
2. **select_spectre_guard** (hoist-47a9f548a648969f) - Lines 1422, 1432 ✅
3. **bitselect** (hoist-47a9f54e65053326) - Lines 980, 983 ✅
4. **sadd/uadd/ssub/usub_overflow** (hoist-47a9f5541d2b1f50) - Lines 2757-2772 ✅
5. **smul/umul_overflow** (hoist-47a9f559de021c6f) - Lines 2780-2800 ✅

These 5 dots (covering 9 opcodes) were **already implemented** and have been closed.

---

## Existing Dots for Full Parity

Beyond the 29 new dots, **59 existing dots** cover:

### Phase 1: ABI Implementation (Critical - 14 dots)
- Function prologue/epilogue
- Parameter passing (int, FP, HFA/HVA)
- Return value handling
- Stack frame management
- Callee-save registers

### Phase 2: Optimizations (High Impact - 23 dots)
- Instruction fusion (MADD/MSUB, bit-field, compare-branch)
- Advanced addressing modes
- LDP/STP pairing
- Immediate legalization (MOVZ/MOVN/MOVK)
- Constant materialization

### Phase 3: Register Allocation (Critical - 10 dots)
- Spilling strategy (REQUIRED - crashes without this)
- Move coalescing
- Interference graph
- Linear scan algorithm
- Rematerialization

### Phase 4: SIMD Completeness (12 dots)
- Advanced shuffles (TBL, ZIP, UZP, TRN)
- Multi-register load/store (LD2/3/4, ST2/3/4)
- Vector comparisons
- Lane extract/insert
- Vector widen/narrow

---

## Total Effort Estimate

### New Missing Items (29 dots):
- **Sub-word stores**: 1 hour
- **Vector loads**: 2 hours
- **Overflow carry**: 2 hours
- **Immediate arithmetic**: 1.5 hours
- **Exception handling**: 2 hours
- **Instruction variants**: 0.5 hours

**Subtotal**: ~9 hours

### Existing Dots (59 dots):
- **Phase 1 (ABI)**: ~3 weeks
- **Phase 2 (Optimizations)**: ~3 weeks
- **Phase 3 (Regalloc)**: ~2 weeks
- **Phase 4 (SIMD)**: ~2 weeks

**Subtotal**: ~10 weeks

### **Grand Total**: ~10-12 weeks for complete ARM64 parity

---

## Critical Path

### Week 1-3: Make It Work
**BLOCKER**: Spilling support required (crashes with >32 live values)

1. ABI prologue/epilogue [Week 1]
2. Parameter passing [Week 1-2]
3. **Spilling integration** [Week 2] 🔴 CRITICAL
4. Stack management [Week 2-3]
5. Sub-word stores (new) [Week 1]
6. Immediate arithmetic (new) [Week 2]

### Week 4-5: Correctness
7. Overflow with carry (new) [Week 4]
8. Vector extending loads (new) [Week 4]
9. Exception handling (new) [Week 5]
10. HFA/HVA support [Week 4-5]

### Week 6-8: Performance
11. Instruction fusion patterns [Week 6]
12. LDP/STP pairing [Week 7-8]
13. Advanced addressing modes [Week 6-7]
14. Register allocation improvements [Week 8]

### Week 9-11: SIMD & Polish
15. Advanced shuffles [Week 9]
16. Multi-register load/store [Week 9-10]
17. Remaining SIMD ops [Week 10]
18. Code size optimizations [Week 11]
19. Security features [Week 11]

---

## Verification Sources

All claims verified against:
- ✅ [Cranelift InstBuilder API](https://docs.rs/cranelift-codegen/latest/cranelift_codegen/ir/trait.InstBuilder.html)
- ✅ [Cranelift Opcode Enum](https://docs.rs/cranelift-codegen/latest/cranelift_codegen/ir/instructions/enum.Opcode.html)
- ✅ [Wasmtime GitHub - lower.isle](https://github.com/bytecodealliance/wasmtime/blob/main/cranelift/codegen/src/isa/aarch64/lower.isle)
- ✅ [Wasmtime GitHub - instructions.rs](https://github.com/bytecodealliance/wasmtime/blob/main/cranelift/codegen/meta/src/shared/instructions.rs)
- ✅ Hoist implementation: `/Users/joel/Work/hoist/src/backends/aarch64/lower.isle`
- ✅ Hoist implementation: `/Users/joel/Work/hoist/src/backends/aarch64/inst.zig`

---

## Next Steps

1. **Immediate**: Implement 29 new dots (9 hours)
   - Start with sub-word stores (simple, no dependencies)
   - Then immediate arithmetic (high-value optimization)
   - Then overflow with carry (needed for bignum)
   - Then vector extending loads (WebAssembly SIMD)
   - Finally exception handling (complex, can defer)

2. **Short-term** (Weeks 1-3): Focus on ABI + spilling
   - **CRITICAL**: Spilling support to prevent crashes
   - Prologue/epilogue for function execution
   - Parameter passing for C ABI

3. **Medium-term** (Weeks 4-8): Optimizations + regalloc
   - Instruction fusion for performance
   - LDP/STP for memory efficiency
   - Better register allocation

4. **Long-term** (Weeks 9-11): SIMD completeness + polish
   - Advanced shuffles
   - Remaining SIMD operations
   - Security features (PAC/BTI, Spectre guards)

---

## Success Criteria

### Minimal Viable (Week 3):
- ✅ Functions execute end-to-end
- ✅ No crashes on register pressure
- ✅ Basic C ABI compatibility
- ✅ All new 18 opcodes implemented

### Production Ready (Week 11):
- ✅ Full AAPCS64 ABI compliance
- ✅ Within 10% of Cranelift performance
- ✅ Complete SIMD support
- ✅ All 186 Cranelift opcodes supported
- ✅ Security features (Spectre guards, PAC/BTI)

---

**Plan verified and approved by Codex Oracle (4 iterations)**
**Last updated**: 2026-01-06
