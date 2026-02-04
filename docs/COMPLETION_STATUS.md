# Hoist JIT Compiler - Completion Status

## Executive Summary

**Status**: Functional AArch64 compiler with ongoing parity work
**Test Coverage**: 2050+ tests (435 integration, 1618 unit)
**Remaining Work**: Active dots in `.dots/` (ABI, exceptions, feature detection, perf)

## Completed (High Confidence)

### Core Infrastructure ✅
- IR representation, CFG, dominance, value lists
- ISLE lowering pipeline
- Constant pools, label resolution, relocations

### AArch64 Core Lowering ✅
- Scalar integer/FP ops, comparisons, shifts, bit-manipulation
- Basic SIMD ops and vector loads/stores
- Atomics and barriers
- TLS models and relocations
- Direct/indirect calls and basic returns

### Testing ✅
- End-to-end JIT tests
- ABI and encoding tests
- TLS and FP special values tests
- Baseline benchmark step: `zig build baseline` writes `/tmp/hoist-baseline-*.log`
- Bench baseline: `zig build bench-log` writes `/tmp/hoist-bench.log`

## Partially Implemented / In Progress

### ABI / Calls ⚠️
- Tail-call ABI conformance (return_call)
- Varargs ABI + lowering
- Struct returns/args (sret)
- Multi-return ABI/emit

### Exception Handling ⚠️
- try_call lowering exists, but exception edges, landing pads, and unwind info are incomplete

### Feature Detection ⚠️
- AArch64 runtime feature probing and plumbing

### Performance Parity ⚠️
- Shuffle pattern coverage
- Dot-product patterns (SDOT/UDOT)
- Addressing modes, peepholes, LICM/partial-loop opts
- Regalloc2 verification + spill/reload audit

## Comparison with Cranelift

### Where Hoist Matches
- IR/SSA fundamentals
- Core AArch64 lowering coverage
- TLS support

### Where Cranelift is Ahead
- ABI completeness (tail calls, varargs, multi-return)
- Exception handling (landing pads + unwind)
- Feature detection and ISA gating
- Optimization depth and testing infrastructure

## Tracking

- Opcode audit and remaining tasks: `docs/arm64_parity_plan.md`
- Feature gaps: `docs/feature_gap_analysis.md`
- Cranelift gap summary: `docs/cranelift_gap_analysis.md`
- Active work items: `.dots/*.md`
