# Feature Gap Analysis - Hoist vs Cranelift (AArch64)

## Executive Summary

**Baseline:** local `/Users/joel/Work/wasmtime/cranelift` (AArch64 backend)
**Last audit:** 2026-02-05

Hoist has broad opcode coverage and core lowering parity on AArch64. Remaining gaps are concentrated in ABI edge cases, exception handling, feature detection, and performance optimizations (shuffle/dotprod patterns, addressing modes, peepholes, and regalloc2 integration/verification). The opcode-level audit and remaining work are tracked in `docs/arm64_parity_plan.md` and active dots in `.dots/`.

## ✅ Fully Implemented (High Confidence)

### Core AArch64 Lowering
- Scalar integer and FP arithmetic, comparisons, shifts, and bit-manipulation
- Vector basics (lane ops, arithmetic, loads/stores)
- Atomics and barriers
- TLS models and relocations
- Constant materialization and literal loads
- Direct/indirect calls and basic returns

### Infrastructure
- ISLE lowering pipeline
- Regalloc2 scaffolding (core integration)
- Object emission foundations (ELF/Mach-O/COFF scaffolding)

## ⚠️ Partially Implemented

### ABI / Calls
- Tail calls (marshaling + frame teardown missing)
- Varargs wiring (signature flags and lowering incomplete)
- Struct returns/args (classification + dedicated tests enabled; marshaling incomplete)
- Multi-return (IR supports; ABI/emit incomplete)

### Feature Detection
- AArch64 feature probing stubbed; flags not fully wired into lowering
- Dot-product patterns gated but detection incomplete

### Optimizations
- Shuffle lowering exists but lacks comprehensive optimal patterns
- Addressing mode coverage incomplete (pairing, complex addressing)
- Peephole and load/store combining incomplete

### Exception Handling
- `try_call` / `try_call_indirect` lowering, CFG exception edges, and LSDA scan paths are implemented
- Remaining: full runtime unwinder and landing-pad integration hardening in end-to-end exception workloads

## ❌ Not Implemented / High Priority Gaps

### Exception Handling
- End-to-end runtime unwinder/landing-pad integration maturity

### ABI Completeness
- Tail-call ABI conformance
- Varargs ABI conformance
- Multi-return ABI/emit
- Full struct return (sret) path

### Performance Parity
- Full shuffle optimization coverage
- Dot-product patterns (SDOT/UDOT)
- Register allocation verification + spill/reload audit

## Priority Classification (Roadmap)

### P0 (Correctness / ABI)
- Tail-call ABI and return_call path
- Varargs ABI + lowering
- Struct returns/args + sret
- Multi-return ABI/emit
- Exception edge wiring

### P1 (Feature Completeness)
- AArch64 feature detection + plumbing
- try_call semantics + unwind/landing pads
- Shuffle pattern completion
- Dot-product patterns gated by feature detection

### P2 (Performance)
- Addressing mode expansion
- Load/store pairing, peepholes, LICM/partial loop opts
- Regalloc2 verification and spill/reload audit

## Tracking

- Opcode audit and missing items: `docs/arm64_parity_plan.md`
- Cranelift gap updates: `docs/cranelift_gap_analysis.md`
- Completion status: `docs/COMPLETION_STATUS.md`
- Active work items: `.dots/*.md`
