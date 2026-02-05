# AArch64 Cranelift Parity (Functional+ABI+Perf)

## Summary
- Baseline: local `/Users/joel/Work/wasmtime/cranelift`
- Goal: close AArch64 functional + ABI + performance parity gaps against Cranelift
- Method: execute existing dots, add/close missing parity dots, and verify with tests + CLIF harness + diff-fuzz
- Merge sources:
  - prior local `/Users/joel/Work/hoist/PLAN.md`
  - `/Users/joel/.claude/plans/fuzzy-sniffing-shamir.md`
  - the parity dot-tree plan captured in this file

## Canonical Execution Order

### 0. Parity Tracking and Baseline
- 0.1 Existing dot: `hoist-cranelift-parity-audit-3a893f8d` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-audit-3a893f8d.md`)
- 0.2 Existing dot: `hoist-update-cranelift-gaps-22b137a8` (`/Users/joel/Work/hoist/.dots/hoist-update-cranelift-gaps-22b137a8.md`)
- 0.3 Existing dot: `hoist-update-feature-gaps-a080115c` (`/Users/joel/Work/hoist/.dots/hoist-update-feature-gaps-a080115c.md`)
- 0.4 Existing dot: `hoist-update-completion-status-83d032e2` (`/Users/joel/Work/hoist/.dots/hoist-update-completion-status-83d032e2.md`)
- 0.5 Existing dot: `hoist-update-parity-docs-4f2077a3` (`/Users/joel/Work/hoist/.dots/hoist-update-parity-docs-4f2077a3.md`)
- 0.6 Existing dot: `hoist-add-backend-matrix-a99c5edd` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-backend-matrix-a99c5edd.md`)
- 0.7 Existing dot: `hoist-add-baseline-checks-6731b0c3` (`/Users/joel/Work/hoist/.dots/hoist-add-baseline-checks-6731b0c3.md`)
- 0.8 Existing dot: `hoist-add-bench-baseline-9f13b2d1` (`/Users/joel/Work/hoist/.dots/hoist-add-bench-baseline-9f13b2d1.md`)
- 0.9 Existing dot: `hoist-add-clif-tool-21564028` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-clif-tool-21564028.md`)
- 0.10 Existing dot: `hoist-add-clif-harness-eea44db9` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-clif-harness-eea44db9.md`)
- 0.11 Existing dot: `hoist-add-clif-tests-ba835276` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-clif-tests-ba835276.md`)
- 0.12 Existing dot: `hoist-add-diff-fuzz-961c3bf9` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-diff-fuzz-961c3bf9.md`)

### 1. Feature Detection and ISA Capability Plumbing
- 1.1 Existing dot: `hoist-aarch64-detect-1c4e9c2c` (`/Users/joel/Work/hoist/.dots/hoist-aarch64-detect-1c4e9c2c.md`)
- 1.2 Existing dot: `hoist-detect-aarch64-features-a0643e73` (`/Users/joel/Work/hoist/.dots/hoist-detect-aarch64-features-a0643e73.md`)
- 1.3 Existing dot: `hoist-feature-detect-7a88da07` (`/Users/joel/Work/hoist/.dots/hoist-feature-detect-7a88da07.md`)
- 1.4 Existing dot: `hoist-feature-plumbing-39b6ae02` (`/Users/joel/Work/hoist/.dots/hoist-feature-plumbing-39b6ae02.md`)
- 1.5 Existing dot: `hoist-wire-feat-use-c13b0065` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-wire-feat-use-c13b0065.md`)
- 1.6 Existing dot: `hoist-wire-native-feat-cd7a6a4b` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-wire-native-feat-cd7a6a4b.md`)
- 1.7 Existing dot: `hoist-add-a64-detect-4f2c1dbd` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-a64-detect-4f2c1dbd.md`)

### 2. ABI and Calling Convention Parity
- 2.1 Existing dot: `hoist-fix-a64-callconv-21cfe2c1` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-fix-a64-callconv-21cfe2c1.md`)
- 2.2 Existing dot: `hoist-abi-parity-e292ce22` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-abi-parity-e292ce22.md`)
- 2.3 Existing dot: `hoist-abi-tailcalls-ca8ca033` (`/Users/joel/Work/hoist/.dots/hoist-abi-tailcalls-ca8ca033.md`)
- 2.4 Existing dot: `hoist-add-tailcall-stack-21c75ca4` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-tailcall-stack-21c75ca4.md`)
- 2.5 Existing dot: `hoist-add-tailcall-restore-aa79e26a` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-tailcall-restore-aa79e26a.md`)
- 2.6 Existing dot: `hoist-wire-varargs-abi-e26b22b7` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-wire-varargs-abi-e26b22b7.md`)
- 2.7 Existing dot: `hoist-wire-varargs-lower-da29c100` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-wire-varargs-lower-da29c100.md`)
- 2.8 Existing dot: `hoist-add-varargs-tests-c1a591a0` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-varargs-tests-c1a591a0.md`)
- 2.9 Existing dot: `hoist-return-marshal-8237ef3b` (`/Users/joel/Work/hoist/.dots/hoist-return-marshal-8237ef3b.md`)
- 2.10 Existing dot: `hoist-indirect-return-b3ed0b57` (`/Users/joel/Work/hoist/.dots/hoist-indirect-return-b3ed0b57.md`)
- 2.11 Existing dot: `hoist-wire-multi-return-65d02a73` (`/Users/joel/Work/hoist/.dots/hoist-wire-multi-return-65d02a73.md`)
- 2.12 Existing dot: `hoist-add-return-tests-8b730002` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-return-tests-8b730002.md`)
- 2.13 Existing dot: `hoist-fix-extname-call-486417f5` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-fix-extname-call-486417f5.md`)
- 2.14 Existing dot: `hoist-add-pic-calls-168bc2ed` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-pic-calls-168bc2ed.md`)
- 2.15 Existing dot: `hoist-trampoline-stubs-b4ca4f68` (`/Users/joel/Work/hoist/.dots/hoist-trampoline-stubs-b4ca4f68.md`)
- 2.16 Existing dot: `hoist-struct-args-tests-4ddf9dee` (`/Users/joel/Work/hoist/.dots/hoist-struct-args-tests-4ddf9dee.md`)

### 3. VMContext, TLS, and Trap Semantics
- 3.1 Existing dot: `hoist-vmctx-reg-c1d37eef` (`/Users/joel/Work/hoist/.dots/hoist-vmctx-reg-c1d37eef.md`)
- 3.2 Existing dot: `hoist-tls-vmctx-954d6fb6` (`/Users/joel/Work/hoist/.dots/hoist-tls-vmctx-954d6fb6.md`)
- 3.3 Existing dot: `hoist-tls-bounds-f80e490b` (`/Users/joel/Work/hoist/.dots/hoist-tls-bounds-f80e490b.md`)
- 3.4 Existing dot: `hoist-trap-fcvtzs-89921e7c` (`/Users/joel/Work/hoist/.dots/hoist-trap-fcvtzs-89921e7c.md`)

### 4. Regalloc2 Integration and Spill/Reload Correctness
- 4.1 Existing dot: `hoist-integrate-regalloc2-8f36d248` (`/Users/joel/Work/hoist/.dots/hoist-integrate-regalloc2-8f36d248.md`)
- 4.2 Existing dot: `hoist-wire-a64-regalloc-c709569d` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-wire-a64-regalloc-c709569d.md`)
- 4.3 Existing dot: `hoist-add-regalloc2-core-e1999642` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-regalloc2-core-e1999642.md`)
- 4.4 Existing dot: `hoist-add-regalloc-verify-9afedffd` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-regalloc-verify-9afedffd.md`)
- 4.5 New dot: `Audit AArch64 spill/reload path`
  - `dot add "Audit AArch64 spill/reload path" -d "Context: /Users/joel/Work/hoist/src/backends/aarch64/isa.zig:343; cause: verify spill/reload path matches regalloc2 expectations for aarch64; fix: adjust spill slot layout or reload insertion if mismatched; deps: hoist-integrate-regalloc2-8f36d248; verification: new aarch64 spill test + zig build test"`

### 5. Vector Lowering and Type Legalization
- 5.1 Existing dot: `hoist-lower-shuffle-b06c30d8` (`/Users/joel/Work/hoist/.dots/hoist-lower-shuffle-b06c30d8.md`)
- 5.2 Existing dot: `hoist-add-shuffle-opt-3dcc9714` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-shuffle-opt-3dcc9714.md`)
- 5.3 Existing dot: `hoist-add-dotprod-patterns-5f9c19ea` (`/Users/joel/Work/hoist/.dots/hoist-add-dotprod-patterns-5f9c19ea.md`)
- 5.4 Existing dot: `hoist-add-dot-product-fedc06ea` (`/Users/joel/Work/hoist/.dots/hoist-add-dot-product-fedc06ea.md`)
- 5.5 Existing dot: `hoist-legalize-vector-types-030df554` (`/Users/joel/Work/hoist/.dots/hoist-legalize-vector-types-030df554.md`)
- 5.6 Existing dot: `hoist-legalize-narrow-types-33b7b6fa` (`/Users/joel/Work/hoist/.dots/hoist-legalize-narrow-types-33b7b6fa.md`)
- 5.7 Existing dot: `hoist-split-wide-types-77640c9e` (`/Users/joel/Work/hoist/.dots/hoist-split-wide-types-77640c9e.md`)
- 5.8 Existing dot: `hoist-legalize-types-ab02b4f7` (`/Users/joel/Work/hoist/.dots/hoist-legalize-types-ab02b4f7.md`)

### 6. Addressing and Optimization Passes
- 6.1 Existing dot: `hoist-add-addr-modes-5ceaa6d9` (`/Users/joel/Work/hoist/.dots/hoist-cranelift-parity-ca8da8b0/hoist-add-addr-modes-5ceaa6d9.md`)
- 6.2 Existing dot: `hoist-peephole-dead-moves-10bef64e` (`/Users/joel/Work/hoist/.dots/hoist-peephole-dead-moves-10bef64e.md`)
- 6.3 Existing dot: `hoist-peephole-load-pairs-51e4d3ae` (`/Users/joel/Work/hoist/.dots/hoist-peephole-load-pairs-51e4d3ae.md`)
- 6.4 Existing dot: `hoist-peephole-redundant-loads-a6b2ed72` (`/Users/joel/Work/hoist/.dots/hoist-peephole-redundant-loads-a6b2ed72.md`)
- 6.5 Existing dot: `hoist-peephole-store-pairs-90328735` (`/Users/joel/Work/hoist/.dots/hoist-peephole-store-pairs-90328735.md`)
- 6.6 Existing dot: `hoist-implement-licm-pass-a4ae5025` (`/Users/joel/Work/hoist/.dots/hoist-implement-licm-pass-a4ae5025.md`)
- 6.7 Existing dot: `hoist-implement-partial-loop-2c8a074d` (`/Users/joel/Work/hoist/.dots/hoist-implement-partial-loop-2c8a074d.md`)
- 6.8 Existing dot: `hoist-optimizer-legalization-eddf172d` (`/Users/joel/Work/hoist/.dots/hoist-optimizer-legalization-eddf172d.md`)

### 7. Exception Handling and try_call Completion
- 7.1 Existing dot: `hoist-exceptions-runtime-d1afab88` (`/Users/joel/Work/hoist/.dots/hoist-exceptions-runtime-d1afab88.md`)
- 7.2 New dot: `Wire try_call exception edges`
  - `dot add "Wire try_call exception edges" -d "Context: /Users/joel/Work/hoist/src/ir/cfg.zig:23 and /Users/joel/Work/hoist/src/codegen/compile.zig (try_call lowering block); cause: verify try_call/try_call_indirect exception successors are plumbed; fix: connect exception edges + landing pads; deps: hoist-exceptions-runtime-d1afab88; verification: add try_call CFG test + zig build test"`
- 7.3 New dot: `Finalize aarch64_try_call lowering`
  - `dot add "Finalize aarch64_try_call lowering" -d "Context: /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig:4191; cause: try_call helpers need final exception metadata/landing pad wiring; fix: complete call emission + exception metadata; deps: Wire try_call exception edges; verification: new aarch64 try_call e2e test"`

### 8. Remaining Opcode Parity Dots (Reconciled 2026-02-05)
- 8.1 `istore8/istore16/istore32` checks are complete and closed:
  - `.dots/archive/hoist-verify-istore8-lowering-ecbda1cb.md`
  - `.dots/archive/hoist-verify-istore16-lowering-5161cfef.md`
  - `.dots/archive/hoist-verify-istore32-lowering-6d9179e9.md`
- 8.2 Widening load checks (`uload8x8/sload8x8/uload16x4/sload16x4/uload32x2/sload32x2`) are complete:
  - `.dots/archive/hoist-verify-simd-widen-b421e77a.md`
  - `.dots/archive/hoist-47cd5e099b396670.md`
- 8.3 Carry/borrow overflow checks (`uadd_overflow_cin/sadd_overflow_cin/usub_overflow_bin/ssub_overflow_bin`) are complete:
  - `.dots/archive/hoist-verify-carry-in-2e75992f.md`
- 8.4 Immediate arithmetic checks (`iadd_imm/irsub_imm/imul_imm`) are complete:
  - `.dots/archive/hoist-47b24cff83e241b8.md`
  - `.dots/archive/hoist-47b24cff91e9e2df.md`
  - `.dots/archive/hoist-47b24cffaf5923e0.md`
- 8.5 `try_call` lowering semantics check is complete:
  - CFG exception reachability fix in `src/codegen/compile.zig`
  - coverage in `tests/e2e_jit.zig`, `src/backends/aarch64/lower_test.zig`, `src/ir/flowgraph.zig`
- 8.6 Evidence report for this reconciliation: `docs/aarch64_opcode_parity_report.md`
- 8.7 Remaining unresolved opcode parity checks in this section: none

### 9. Object Emission and Relocations
- 9.1 Existing dot: `hoist-obj-emission-ad51d2ad` (`/Users/joel/Work/hoist/.dots/hoist-obj-emission-ad51d2ad.md`)
- 9.2 Existing dot: `hoist-add-elf-section-d90d3c17` (`/Users/joel/Work/hoist/.dots/hoist-add-elf-section-d90d3c17.md`)
- 9.3 Existing dot: `hoist-add-elf-symtab-c233787d` (`/Users/joel/Work/hoist/.dots/hoist-add-elf-symtab-c233787d.md`)
- 9.4 Existing dot: `hoist-add-mach-o-b3d199a0` (`/Users/joel/Work/hoist/.dots/hoist-add-mach-o-b3d199a0.md`)
- 9.5 Existing dot: `hoist-add-coff-section-729c5f12` (`/Users/joel/Work/hoist/.dots/hoist-add-coff-section-729c5f12.md`)
- 9.6 Existing dot: `hoist-coff-writer-76e95f19` (`/Users/joel/Work/hoist/.dots/hoist-coff-writer-76e95f19.md`)
- 9.7 Existing dot: `hoist-finish-elf-writer-03a39ee4` (`/Users/joel/Work/hoist/.dots/hoist-finish-elf-writer-03a39ee4.md`)
- 9.8 Existing dot: `hoist-finish-mach-o-42e5a740` (`/Users/joel/Work/hoist/.dots/hoist-finish-mach-o-42e5a740.md`)
- 9.9 Existing dot: `hoist-finish-coff-writer-7776ad8b` (`/Users/joel/Work/hoist/.dots/hoist-finish-coff-writer-7776ad8b.md`)
- 9.10 Existing dot: `hoist-fix-elf-reloc-0c013c4d` (`/Users/joel/Work/hoist/.dots/hoist-fix-elf-reloc-0c013c4d.md`)
- 9.11 Existing dot: `hoist-fix-coff-reloc-e80dd588` (`/Users/joel/Work/hoist/.dots/hoist-fix-coff-reloc-e80dd588.md`)
- 9.12 Existing dot: `hoist-fix-mach-o-e88db236` (`/Users/joel/Work/hoist/.dots/hoist-fix-mach-o-e88db236.md`)
- 9.13 Existing dot: `hoist-fix-obj-writers-75b5006b` (`/Users/joel/Work/hoist/.dots/hoist-fix-obj-writers-75b5006b.md`)
- 9.14 Existing dot: `hoist-branch-relocs-77085a9b` (`/Users/joel/Work/hoist/.dots/hoist-branch-relocs-77085a9b.md`)

## Public APIs / Interfaces
- AArch64 ABI surface in `/Users/joel/Work/hoist/src/codegen/compile.zig` and `/Users/joel/Work/hoist/src/machinst/abi.zig` (`CallLayout`, varargs, multi-return)
- Exception edge representation in `/Users/joel/Work/hoist/src/ir/cfg.zig` if expanded
- ISA feature detection API in `/Users/joel/Work/hoist/src/backends/aarch64/isa.zig`

## Tests and Verification
- Run `zig build test -j1 --global-cache-dir .zig-global-cache` after each dot
- Add targeted AArch64 lowering tests for: store8/16/32, widen loads, overflow_cin/bin, imm ops, try_call
- Extend `/Users/joel/Work/hoist/tests/e2e_jit.zig`, `/Users/joel/Work/hoist/tests/aarch64_tls.zig`, `/Users/joel/Work/hoist/tests/fp_special_values.zig`
- Run CLIF harness + diff-fuzz after harness wiring to validate parity against local Cranelift baseline

## Assumptions / Defaults
- Scope: functional + ABI + performance parity for AArch64
- This file is the canonical, committable merged plan
- Source parity plan remains available at `/Users/joel/.claude/plans/fuzzy-sniffing-shamir.md` for provenance

---

## Appendix A: Previous `/Users/joel/Work/hoist/PLAN.md` (verbatim)

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

---

## Appendix B: `/Users/joel/.claude/plans/fuzzy-sniffing-shamir.md` (verbatim)

# Cranelift Parity Gap Analysis

## Summary

Hoist has 276 ISLE rules vs Cranelift's 225 (123% rule coverage), but several categories remain incomplete or unimplemented for full parity.

**Open Dots**: 158 total, 111 specifically for Cranelift parity

---

## CRITICAL MISSING (Blocking)

### 1. ISLE Compiler Infrastructure
**Location**: `src/dsl/isle/`
- Pattern matching codegen incomplete (`codegen/match.zig:244` - if-let)
- Constructor codegen incomplete (`codegen/constructors.zig:107-118`)
- No optimization passes for decision tree (`codegen/match.zig:344`)
- Nested pattern bindings unhandled (`codegen/extractors.zig:173`)

### 2. Block Parameters (Phi Functions)
**Location**: `src/codegen/compile.zig:734`
- `TODO: Block parameters not yet implemented in IR`
- Required for proper SSA representation with loop-carried values

### 3. Tail Calls (return_call)
**Location**: `src/backends/aarch64/isle_impl.zig:2211-2287`
- Argument marshaling not implemented
- Frame size calculation stubbed
- External function name lookup missing
- `@panic("TODO: Wire up external function name lookup...")` at line 2254

### 4. Exception Handling
**Location**: `src/backends/aarch64/isle_helpers.zig:4228`
- Landing pads not wired
- Unwind info not generated
- Exception edges not in CFG

### 5. x86-64 Backend
**Location**: `src/backends/x64/`
- Lowering: stub only
- Emission: CALL rel32 stub only
- Pipeline stages TODO at `src/codegen/compile.zig:4723-4755`

---

## HIGH PRIORITY MISSING

### 1. Struct ABI (HFA/HVA)
**Locations**:
- `src/backends/aarch64/isle_helpers.zig:3059,3567` - Stack HFA handling TODO
- `src/backends/aarch64/isle_helpers.zig:3179,3687` - HVA struct class TODO
- `src/backends/aarch64/abi.zig:1549,3712` - Struct introspection TODO

### 2. Multi-Return Values
**Location**: `src/backends/aarch64/isle_helpers.zig:3872`
- `TODO: Extend ValueRegs to support more return values`
- Currently returns single X0 only

### 3. Overflow Arithmetic (8 rules)
**Opcodes**: `sadd_overflow`, `ssub_overflow`, `smul_overflow`, `uadd_overflow`, `usub_overflow`, `umul_overflow`
- 0% coverage in Hoist
- Required for Rust/Swift checked arithmetic

### 4. Shuffle Patterns (32 rules)
**Status**: Shuffle opcode exists but limited patterns
- Missing: dup, ext, uzp1/uzp2, zip1/zip2, trn1/trn2, rev16/32/64
- 15% of real-world SIMD ops use shuffle

### 5. VFP Immediate Encoding
**Location**: `src/backends/aarch64/isle_helpers.zig:6751,6758`
- `TODO: Support full VFPExpandImm encoding (±n/16 × 2^r)`

---

## MEDIUM PRIORITY MISSING

### 1. Register Allocation Quality
- regalloc2 integration stubbed (`src/backends/aarch64/isa.zig:280`)
- Register coalescing incomplete
- Rematerialization not implemented
- Spill coalescing (STP vs 2×STR) not implemented

### 2. Optimization Passes
| Pass | Location | Status |
|------|----------|--------|
| LICM | `src/codegen/optimize.zig:168` | TODO: CFG reconciliation |
| Load-pair | `src/codegen/peephole.zig:99` | TODO |
| Store-pair | `src/codegen/peephole.zig:117` | TODO |
| Dead move elim | `src/codegen/peephole.zig:127` | TODO |
| Copy propagation | N/A | Not implemented |
| Div-by-constant | N/A | Not implemented |

### 3. Vector Test Operations
- `vhigh_bits` (4 rules) - extract sign bits
- `vall_true`, `vany_true` (4 rules) - lane predicates

### 4. Immediate Extraction Patterns
Missing from ISLE vs Cranelift:
- `imm12_from_value` / `imm12_from_negated_value`
- `extended_value_from_value` (fold sign/zero extend into arithmetic)
- `iadd_ishl` shift-fold patterns

---

## LOW PRIORITY / DEFERRABLE

### 1. Special/ABI Operations (14 rules)
- `get_frame_pointer`, `get_stack_pointer`, `get_return_address`
- Debugging intrinsics
- `select_spectre_guard`

### 2. Type System Enhancements
- `Ieee16`, `Ieee128` support (`src/codegen/data_value.zig:21,24`)
- `I8X8`, `I8X4`, `I8X2` proper types (`src/codegen/data_value.zig:53-55`)
- Dynamic SIMD (SVE)

### 3. Libcall Signatures
**Location**: `src/ir/libcall.zig:161`
- `@panic("unimplemented libcall signature")`

### 4. Scalable Vectors
**Location**: `src/backends/aarch64/isle_impl.zig:1428`
- `@panic("TODO: dyn_scale_target_const")`

---

## TODO/FIXME Summary

| Category | Count | Critical |
|----------|-------|----------|
| ISLE compiler | 9 | Yes |
| Codegen pipeline | 15 | Yes |
| AArch64 backend | 35 | Partial |
| Optimization passes | 12 | No |
| IR/verification | 14 | No |
| Tests (verification) | 33 | No |
| **Total** | **118** | |

---

## Implementation Phases for 100% Parity

### Phase 1: Core Infrastructure (1-2 weeks)
1. Block parameters in IR
2. Complete ISLE pattern matching codegen
3. Tail call argument marshaling

### Phase 2: ABI Completeness (1 week)
1. HFA/HVA struct passing
2. Multi-return values (X0:X1, V0:V1, etc.)
3. Stack argument handling fixes

### Phase 3: Missing Opcodes (1-2 weeks)
1. Overflow arithmetic (8 rules)
2. Shuffle patterns (32 rules)
3. Vector tests (vhigh_bits, vall_true, vany_true)

### Phase 4: Optimization Quality (2-3 weeks)
1. regalloc2 integration
2. LICM pass completion
3. Peephole optimizer (load/store pair, dead moves)
4. Division-by-constant optimization

### Phase 5: Exception Handling (1-2 weeks)
1. Landing pad infrastructure
2. Exception edge wiring
3. Unwind info generation

### Phase 6: x86-64 Backend (3-4 weeks)
1. Complete instruction selection
2. ABI implementation
3. Emission pipeline

---

## Files to Modify

### Critical Path
- `src/codegen/compile.zig` - block params, pipeline
- `src/backends/aarch64/isle_impl.zig` - tail calls
- `src/backends/aarch64/isle_helpers.zig` - HFA/HVA, exceptions
- `src/dsl/isle/codegen/*.zig` - ISLE compiler

### Secondary
- `src/backends/aarch64/abi.zig` - struct classification
- `src/codegen/peephole.zig` - optimizations
- `src/ir/opcodes.zig` - overflow ops
- `src/generated/aarch64_lower_generated.zig` - lowering rules

---

## OPEN/UNCLEAR/UNDER-SPECIFIED

### 1. Register Allocator Strategy (UNCLEAR)
**Location**: `src/machinst/compile.zig:119`
- Currently uses linear scan
- "TODO: Integrate regalloc2" but no decision on:
  - When to switch?
  - Parallel allocator support?
  - Backtracking vs greedy?

### 2. E-graph Optimization Extraction (UNSPECIFIED)
**Location**: `src/codegen/compile.zig:798`
- E-graph runs but "TODO: Extract optimized IR back"
- No algorithm specified for reconstructing IR from e-graph
- Blocking for optimization improvements

### 3. CFG Type Reconciliation (BLOCKING)
**Location**: `src/codegen/optimize.zig:168`
- Two CFG representations exist
- LICM blocked: "requires reconciling CFG types"
- No decision on which to standardize

### 4. External Symbol Resolution (STUBBED)
**Location**: `src/backends/aarch64/isle_helpers.zig:3753-3763`
- ExternalName→symbol mapping stubbed
- "proper symbol resolution TBD"
- Blocks correct external calls and object emission

### 5. Tail Call Stack Args (UNIMPLEMENTED)
**Location**: `src/backends/aarch64/isle_helpers.zig:3217-3223`
- Stack arguments rejected for tail calls
- Overlap-safe layout algorithm not specified
- Spec unclear: copy before or after frame pop?

### 6. Multi-Return ABI (PARTIAL)
**Location**: `src/backends/aarch64/isle_helpers.zig:3771-3879`
- Errors on >2 returns
- Need: extend ValueRegs, plumb through lowering
- Dep: hoist-extend-value-regs-e2cf4d2a

### 7. Phi/Block Parameter IR Design (MISSING)
**Location**: `src/codegen/compile.zig:728-738`
- `removeConstantPhis()` stubbed
- Block parameters not in IR
- Design decision: implicit phis vs explicit block params?

### 8. ISLE Compiler (INCOMPLETE)
Multiple unfinished subsystems:
- If-let compilation (`codegen/match.zig:244`)
- Equality constraint selection (`trie.zig:706`)
- Nested pattern bindings (`extractors.zig:173`)
- Decision tree optimization (`match.zig:344`)

### 9. Vector Type System (INCOMPLETE)
**Location**: `src/codegen/data_value.zig:52-55`
- All v16/v32/v64 default to I8X16
- Missing: I8X2, I8X4, I8X8 proper types
- Unclear: how to distinguish lane widths?

### 10. Scalable Vectors / SVE (NO SPEC)
**Location**: `src/backends/aarch64/isle_impl.zig:1428`
- `@panic("TODO: dyn_scale_target_const")`
- No design for runtime-determined vector lengths
- Unclear if in scope

### 11. Platform Detection (HARDCODED)
**Location**: `src/backends/aarch64/isle_impl.zig:2982,2997`
- VM context reg hardcoded to X28
- "TODO: Platform detection"
- No abstraction for platform-specific ABI

### 12. Exception Control Flow (UNINTEGRATED)
**Locations**:
- `aarch64_lower_generated.zig:1674,1677` - trap labels
- `aarch64_lower_generated.zig:2665` - try-call exceptions
- Label allocation not integrated with exception edges
- Landing pad routing unspecified

---

## Questions for Decision

1. **regalloc2**: Port Cranelift's allocator or implement independent?
2. **E-graph extract**: Use Cranelift's algorithm or simpler greedy?
3. **Block params**: Add to IR or keep implicit phis?
4. **SVE**: In scope for parity or defer?
5. **x86-64**: Full backend or stub for testing?
6. **Module/JIT layer**: Port Cranelift's or different design?

---

## SPECIFIC @panic POINTS (Will crash at runtime)

| Location | Trigger | Description |
|----------|---------|-------------|
| `isle_impl.zig:2254` | return_call with external func | "Wire up external function name lookup" |
| `isle_impl.zig:1429` | Scalable vectors | "dyn_scale_target_const for scalable vectors" |
| `isle_impl.zig:2933` | vldr with non-64/128 bit | "unsupported vector size" |
| `emit.zig:432` | Any unhandled inst type | "Unimplemented instruction in emit" |
| `emit.zig:440` | VReg reaches emit | "Virtual register reached emit stage" |
| `libcall.zig:161` | probestack/elf_tls_* | "unimplemented libcall signature" |
| `aarch64_lower_generated.zig:2651` | try_call bad funcref | "FuncRef not found in metadata" |

---

## UNSUPPORTED ERROR RETURNS (Partial implementation)

| Error | Location | Meaning |
|-------|----------|---------|
| `UnsupportedHVA` | `machinst/abi.zig:352` | Vector aggregates not handled |
| `UnsupportedRegCount` | `isle_ctx.zig:107` | >2 return values |
| `UnsupportedType` | `isle_helpers.zig:1530,1680,2255,6738` | Various type lowerings |
| `UnsupportedIntegerSize` | `isle_impl.zig:1231,1308` | Non-8/16/32/64 bit ints |
| `UnsupportedFloatSize` | `isle_impl.zig:1249,1326` | Non-32/64 bit floats |
| `UnsupportedAtomicOrdering` | `isle_helpers.zig:764` | Unknown memory ordering |
| `UnsupportedCallConv` | `compile.zig:484` | Non-SystemV/AAPCS call conv |
| `UnsupportedOp` | `sccp.zig:506,581` | SCCP can't handle op |
| `UnsupportedLogicalImmediate` | `emit.zig:1286,1320,1354,1475` | Imm can't encode |
| `UnsupportedFPImmediate` | `emit.zig:231,241,3871,3894` | FP imm can't encode |

---

## OPCODES RETURNING FALSE (Not lowered)

Lowering file returns false for these (from `aarch64_lower_generated.zig`):
- `trapz`, `trapnz` - Need label allocation for trap handling
- `try_call` - Exception infrastructure incomplete (DOT 3)
- Stack ops with missing slot_data
- Various fallthrough cases (82 total `return false`)

---

## LIBCALL SIGNATURES MISSING

In `src/ir/libcall.zig:160-162`:
- `probestack` - Stack overflow probing
- `elf_tls_get_addr` - ELF TLS address lookup
- `elf_tls_get_offset` - ELF TLS offset lookup

---

## OPEN DOT COUNT BY CATEGORY

From `.dots/` directory:
- **Total open**: 158 dots
- **Cranelift parity**: 111 dots in `hoist-cranelift-parity-ca8da8b0/`
- **ABI/emit fixes**: ~15 dots
- **FP tests/helpers**: 4 dots
- **Various fixes**: ~28 dots

Key parity dots:
- `hoist-fix-extname-call` - External symbol resolution
- `hoist-fix-const-phis` - Phi removal stubbed
- `hoist-wire-multi-return` - >2 returns error
- `hoist-add-tailcall-stack` - Stack args rejected
- `hoist-extend-value-regs` - ValueRegs limited to 2
- `hoist-add-egraph-extract` - E-graph → IR missing

---

## TEST VERIFICATION TODOS

From test files (33 items):
- TLS disassembly verification
- CCMP sequence verification
- Indirect return verification
- Stack arg spacing/alignment
- Struct/HFA/HVA passing
- Tail call sequence verification

All await disassembler implementation for validation.

---

## SEMANTIC EDGE CASES & UNCLEAR BEHAVIOR

### ABI Differences (May break compatibility)

| Issue | Location | Risk |
|-------|----------|------|
| X18 reserved Darwin only | `abi.zig:821` | Cross-platform code fails silently on Darwin |
| Red zone Darwin disabled | `abi.zig:153-158` | Leaf function optimization differs |
| HFA stack layout | `isle_helpers.zig:3059,3567,4009` | TODO - variadic with HFA fails |
| Register pair alignment | `abi.zig:276,293` | Misaligned pairs silently corrupt |
| X8 indirect return | `abi.zig:819` | Large returns need caller buffer |
| Exception via X0 | `abi.zig:28-149` | X0 dual-purpose may conflict |

### Float Semantics (NaN/special values)

| Issue | Location | Status |
|-------|----------|--------|
| FloatCC.ueq expansion | `legalize.zig:54-61` | null - not expanded |
| FloatCC.one expansion | `legalize.zig:54-61` | null - not expanded |
| FloatCC.ult/ule/ugt/uge | `legalize.zig:54-61` | null - not expanded |
| Soft-float F16/F128 | `legalize_ops.zig:146-149` | Delegates to libcalls |

### Integer Semantics

| Issue | Location | Note |
|-------|----------|------|
| Vector shift masking | `isle_helpers.zig:6320-6323` | Wraps rather than saturates |
| UREM expansion | `legalize_ops.zig:65` | `a - (a/b)*b` - verify overflow |
| Div magic numbers | `div_const.zig` | Off-by-one risk at boundaries |

### Encoding Edge Cases

| Issue | Location | Impact |
|-------|----------|--------|
| Logical imm limits | `encoding.zig:155-267` | Some 64-bit vals can't encode |
| MOV synthesis (3 chunks) | `legalize.zig:140-157` | 4+ chunks → literal pool |
| Offset alignment strict | `legalize.zig:198-200` | Must be size-aligned |

### Platform-Specific Behavior

| Platform | Difference | Impact |
|----------|------------|--------|
| Darwin | X18 reserved, no red zone | Fewer scratch regs, leaf fns different |
| Linux | Standard AAPCS64 | Full red zone, X18 available |
| Windows | Falls back to AAPCS64 | `windows_fastcall` → `aapcs64()` |

---

## UNVERIFIED CRANELIFT COMPATIBILITY

These behaviors need verification against Cranelift:

1. **Vector shift amount masking** - Does Cranelift mask or saturate?
2. **Soft-float calling convention** - Same libcall signatures?
3. **HFA field ordering** - Little-endian lane assembly order?
4. **Exception ABI** - X0 null vs exception pointer semantics?
5. **Division magic constants** - Same algorithm as Hacker's Delight?
6. **Logical immediate fallback** - Same literal pool strategy?

---

## INCOMPLETE FLOAT COMPARISON EXPANSION

From `src/backends/aarch64/legalize.zig:54-61`:
```
.ueq => null,  // unordered or equal
.one => null,  // ordered not equal
.ult => null,  // unordered less than
.ule => null,  // unordered less or equal
.ugt => null,  // unordered greater than
.uge => null,  // unordered greater or equal
```
These return `null` meaning NO EXPANSION - code using these will fail.

---

## SILENT FAILURES (Emit NOP instead of error)

From `src/codegen/compile.zig`:
- Line 2354: `// Other binary ops not yet implemented` → emits NOP
- Line 4047: `// Other unary ops not yet implemented` → emits NOP

These silently produce incorrect code rather than failing compilation.

---

## STUB RETURNS FALSE (Instruction not lowered)

| File | Line | Context |
|------|------|---------|
| `aarch64_lower_generated.zig` | 2679 | "instruction not handled" |
| `machinst/lower.zig` | 419 | "Instruction not handled - this is an error" |
| `aarch64/lower.zig` | 27,117 | "Fallback for instructions not handled by ISLE" |
| `x64/lower.zig` | 100 | "Stub returns false" |

---

## SUMMARY: What's Truly Unclear

### Design Decisions RESOLVED

| Decision | Choice |
|----------|--------|
| regalloc2 | Port Cranelift's regalloc2 |
| x86-64 backend | Defer entirely |
| SVE/scalable vectors | Yes, full SVE support |
| Silent NOP failures | Implement all ops |
| Block params/phis | SSA builder approach |
| E-graph extraction | Port Cranelift's algorithm |
| FloatCC NaN expansion | Multi-instruction expansion |
| Exception handling | Full landing pads |
| HFA/HVA stack passing | High priority |
| Multi-return (>2) | Extend ValueRegs |
| External symbols | Module-based system |
| Libcall signatures | Implement now |
| Tail call stack args | Match Cranelift's algorithm |
| Platform ABI (Darwin/Linux) | Compile-time flag (target spec) |
| Test verification | Build basic AArch64 disassembler |
| regalloc2 translation | Zig idioms (rewrite, not direct port) |
| Module system | Full ecosystem (module + object + JIT) |
| Shuffle patterns | All 32 patterns |
| SVE approach | Port Cranelift's implementation |
| Disassembler | Capstone wrapper |
| Differential testing | All three levels (IR, bytes, execution) |
| Unwind format | Compact first (Apple), DWARF later |
| SSA builder | Full construction (like Cranelift's) |
| Module crates | All three (module + object + JIT) |
| ISLE completion | Both (if-let + decision tree together) |
| Capstone integration | System library |
| Div verify | Cranelift's constants |
| SIMD tests | Cranelift output comparison |
| Atomic tests | Multi-threaded stress tests |
| Const pool | Subsumption deduplication |
| Function inlining | Yes, include |
| NaN canonicalization | Yes, include |
| Alias analysis | Yes, include |
| Loop opts | Both (LICM + unrolling) |
| Peephole optimizer | All patterns |
| Reference types | Yes, include |
| CCMP patterns | Yes, include |
| Spectre mitigations | Yes, include |
| Debug info | Full DWARF |
| Probestack | Yes, include |
| Jump tables (br_table) | Full support with CFG edges |
| CPU feature detection | Runtime detection |
| Narrow vector types | Yes, implement (I8X2, I8X4, I8X8) |
| F16/F128 soft-float | Yes, full support |
| Overflow arithmetic | Yes, all 8 rules |
| Dot product patterns | Yes, include (SDOT/UDOT) |
| PIC/GOT calls | Yes, complete (ADRP+LDR+BLR) |
| Signature validation | Yes, complete |
| VFP immediate encoding | Yes, full VFPExpandImm |
| Struct copy barriers | Yes, add DMB barriers |
| Benchmarking | Match Cranelift's benchmarks |
| Thread safety | Fully parallel compilation |
| API style | Zig-idiomatic (may differ from Cranelift) |

### Semantic Behavior Unverified
1. Vector shift masking vs saturation
2. Soft-float libcall signatures
3. Exception X0 semantics vs Cranelift
4. Division magic number edge cases
5. HFA field ordering endianness

### Silent Failure Paths
1. Unhandled binary/unary ops → NOP
2. FloatCC unordered comparisons → null
3. Tail calls with stack args → log error + fail
4. >2 return values → log error + fail

### Test Coverage Gaps
1. ~~No disassembler to verify output~~ → Build disassembler
2. 33 TODOs awaiting verification infrastructure
3. No differential testing vs Cranelift

---

## IMPLEMENTATION ORDER (Based on decisions)

### Phase 1: Foundation
1. **Build AArch64 disassembler** - Enables all verification
2. **Implement all missing binary/unary ops** - Fix silent NOPs
3. **Complete libcall signatures** (probestack, elf_tls_*)
4. **Add compile-time platform target spec**

### Phase 2: Core Infrastructure
5. **Port regalloc2** from Cranelift
6. **Add SSA builder** for block parameters
7. **Port e-graph extraction algorithm**
8. **Implement module-based symbol resolution**

### Phase 3: ABI Completeness
9. **HFA/HVA stack passing** (high priority)
10. **Extend ValueRegs for >2 returns**
11. **Tail call stack args** (match Cranelift)
12. **Multi-instruction FloatCC NaN expansion**

### Phase 4: Advanced Features
13. **Full SVE support**
14. **Full landing pad exception handling**
15. **Complete shuffle patterns** (32 ISLE rules)

### Verification
- Run `zig build test` after each change
- Use Capstone to verify instruction encoding
- Compare behavior vs Cranelift reference where possible
- Multi-threaded stress tests for atomics
- Differential testing at IR, bytes, and execution levels

---

## REVISED IMPLEMENTATION ORDER (Full 100% Parity)

### Phase 1: Foundation & Tooling
1. Capstone disassembler wrapper (system library)
2. Implement all missing binary/unary ops (remove silent NOPs)
3. Complete libcall signatures (probestack, elf_tls_*)
4. Add compile-time platform target spec
5. Implement narrow vector types (I8X2, I8X4, I8X8)

### Phase 2: Core Infrastructure
6. Port regalloc2 (Zig idioms, not direct port)
7. SSA builder (full construction like Cranelift)
8. Port e-graph extraction algorithm from Cranelift
9. Module system (full: module + object + JIT crates)
10. External symbol resolution (module-based)

### Phase 3: ABI Completeness
11. HFA/HVA stack passing (high priority)
12. Extend ValueRegs for >2 returns
13. Tail call stack args (match Cranelift algorithm)
14. Multi-instruction FloatCC NaN expansion
15. Complete signature validation
16. PIC/GOT calls (ADRP+LDR+BLR)
17. Struct copy barriers (DMB)

### Phase 4: Opcodes & Patterns
18. Overflow arithmetic (all 8 rules)
19. All 32 shuffle patterns
20. CCMP patterns
21. Dot product patterns (SDOT/UDOT)
22. Complete VFP immediate encoding
23. Spectre mitigations

### Phase 5: Optimization Passes
24. Alias analysis
25. LICM + loop unrolling
26. Peephole optimizer (all patterns)
27. Function inlining
28. NaN canonicalization
29. Constant pool subsumption

### Phase 6: Advanced Features
30. Full SVE support (port Cranelift's)
31. Full landing pad exception handling
32. Apple compact unwind (DWARF later)
33. F16/F128 soft-float
34. Reference types (externref, funcref)
35. Jump tables with CFG edges
36. Runtime CPU feature detection
37. DWARF debug info
38. Probestack

### Phase 7: Testing & Validation
39. ISLE compiler completion (if-let + decision tree)
40. Match Cranelift's benchmarks
41. Differential testing (all three levels)
42. Multi-threaded atomic stress tests
43. Parallel compilation support

---

## TOTAL SCOPE

- **New dots created**: 90+ (see `.dots/` directory)
- **Previous open dots**: 158 (111 parity-specific)
- **@panic points to fix**: 7
- **Unsupported error returns**: 10+
- **Silent NOP failures**: 2
- **Design decisions resolved**: 35+
- **Target**: 100% Cranelift parity (AArch64)

---

## NEW DOTS CREATED (by phase)

### Phase 1: Foundation & Tooling (8 dots)
- hoist-add-capstone-disasm-df942d80
- hoist-fix-silent-nop-07d8ab1a (binary ops)
- hoist-fix-silent-nop-77b95a9a (unary ops)
- hoist-add-probestack-libcall-45fbd7d6
- hoist-add-elf-tls-* (2 dots)
- hoist-add-platform-target-974dabe4
- hoist-add-i8x2/i8x4/i8x8 (3 dots)

### Phase 2: Core Infrastructure (15 dots)
- regalloc2: data, liveness, coloring, wire (4 dots)
- SSA builder: struct, phi insert, prune, wire (4 dots)
- e-graph: struct, cost model, wire (3 dots)
- Module: struct, symbol table, object, JIT (4 dots)

### Phase 3: ABI Completeness (13 dots)
- HFA/HVA: stack, struct class, introspection (3 dots)
- ValueRegs extend, multi-return wire (2 dots)
- Tail call: stack copy, indirect wire (2 dots)
- FloatCC NaN: ueq, one, unordered variants (3 dots)
- Signature validation, PIC calls, DMB barriers (3 dots)

### Phase 4: Opcodes & Patterns (20 dots)
- Overflow: uadd, sadd, usub, ssub, umul, smul, trap (7 dots)
- Shuffle: DUP, EXT, UZP, ZIP, TRN, REV, TBL (7 dots)
- CCMP: AND, OR (2 dots)
- Dot product: SDOT, UDOT (2 dots)
- VFP immediate, Spectre guard/fence (3 dots)

### Phase 5: Optimization Passes (12 dots)
- Alias: struct, points-to, queries (3 dots)
- LICM, loop unrolling (2 dots)
- Peephole: load-pair, store-pair, dead move, redundant load (4 dots)
- Inliner: struct, wire (2 dots)
- NaN canon, const pool subsumption (2 dots)

### Phase 6: Advanced Features (20 dots)
- SVE: types, registers, ops, dyn_scale (4 dots)
- Exception: landing pad, CFG edges, try_call, unwind (4 dots)
- F16/F128 soft-float (2 dots)
- Reference types: externref, funcref (2 dots)
- Jump tables, CPU detect, wire features (3 dots)
- DWARF: line, frame, wire (3 dots)
- Probestack emission (1 dot)

### Phase 7: Testing & Validation (11 dots)
- ISLE: if-let, decision tree, nested, equality (4 dots)
- Benchmarks, diff testing IR/bytes/exec (4 dots)
- Atomic stress, parallel compile, div verify (3 dots)

### Bug Fixes (4 dots)
- Fix external name, vldr vector, emit unimpl, vreg at emit

---

## POST-PLAN ACTIONS

After exiting plan mode:
1. Update AGENTS.md to link to this plan
2. Run `dot list` to review all dots
3. Begin implementation with Phase 1 dots
