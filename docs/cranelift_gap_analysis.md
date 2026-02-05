# CRANELIFT vs HOIST ARM64 GAP ANALYSIS

## Executive Summary

**Baseline:** `/Users/joel/Work/wasmtime/cranelift` (AArch64 backend)
**Last audit:** 2026-02-05

Opcode-level gaps that were previously listed here are now outdated. The current parity gaps are primarily **ABI correctness**, **exception handling**, **feature detection**, and **performance optimizations** (shuffle/dotprod patterns, addressing modes, peepholes). The opcode audit and remaining work items are tracked in:

- `docs/arm64_parity_plan.md`
- `docs/feature_gap_analysis.md`
- `.dots/*.md`

## Updated Gap Areas

### ABI / Calls (Correctness)
- Tail-call ABI conformance and return_call lowering
- Varargs ABI + lowering
- Struct returns/args (sret marshaling) and multi-return ABI/emit

### Exception Handling (Correctness)
- Exception edges in CFG/emit
- Landing pad metadata + unwind info

### Feature Detection (Correctness/Perf)
- Runtime AArch64 feature probing and plumbing
- Dot-product gating (SDOT/UDOT)

### Performance Parity
- Full shuffle pattern coverage
- Addressing modes + LDP/STP pairing
- Peephole optimizations and loop opts
- Regalloc2 verification + spill/reload audit

## Notes

- Lowering coverage has expanded; remaining work is mostly **infrastructure and integration** rather than missing opcodes.
- For a verified opcode list and remaining tasks, use `docs/arm64_parity_plan.md`.
