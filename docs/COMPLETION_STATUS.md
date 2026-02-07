# Hoist JIT Compiler - Completion Status

## Executive Summary

**Status**: Functional AArch64 compiler with active parity closure
**Test Coverage**: 2050+ tests (435 integration, 1618 unit)
**Remaining Work**: Parity backlog in ABI, exceptions, feature detection, and performance

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
- AAPCS64 struct ABI classification for general/HFA/HVA args and returns

### Testing ✅
- End-to-end JIT tests
- ABI and encoding tests
- TLS and FP special values tests
- AArch64 struct-arg ABI classification tests (`tests/aarch64_struct_args.zig`)
- Baseline benchmark step: `zig build baseline` writes `/tmp/hoist-baseline-*.log`
- Bench baseline: `zig build bench-log` writes `/tmp/hoist-bench.log`

## Partially Implemented / In Progress

### ABI / Calls ⚠️
- Tail-call ABI conformance (return_call)
- Varargs ABI + lowering
- Struct returns/args classification and sret routing are implemented; remaining work is deeper end-to-end struct result-value coverage
- Multi-return ABI/emit

### Exception Handling ⚠️
- `try_call` / `try_call_indirect` lowering, CFG exception edges, and LSDA call-site scanning are implemented
- E2E tests now use real external function metadata for `try_call` paths and validate AArch64 compile output
- Remaining: full runtime unwinder/landing-pad integration validation across full e2e workloads

## Recent Completed Work

- `5aed7747`: Added differential JIT/model fuzz harness in `fuzz/fuzz_compile.zig` and wired reproducible mismatch reporting
- `e5ca8f13`: Rewrote `fuzz/fuzz_regalloc.zig` for current allocator API, restored `zig build fuzz`, and added unsupported-class handling in `src/machinst/regalloc.zig`
- `6dc6cd6a`: Implemented AAPCS64 HVA argument mapping in `src/machinst/abi.zig`
- `6d497e4e`: Fixed <=16B general struct argument chunking into X-register slots
- `b2e6c627`: Implemented AAPCS64 struct return slot mapping (X0/X1, V0+, X8 sret)
- `30aa6ab1`: Replaced placeholder `try_call` function refs with real metadata in e2e tests
- `1890008d`: Added AArch64-gated compile validation for `try_call` e2e tests and fixed type mismatches
- `c37e0e0e`: Removed debug-print noise from JIT e2e tests

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
- Exception runtime maturity (full landing-pad + unwind integration depth)
- Feature detection and ISA gating
- Optimization depth and testing infrastructure

## Tracking

- Opcode audit and remaining tasks: `docs/arm64_parity_plan.md`
- Feature gaps: `docs/feature_gap_analysis.md`
- Cranelift gap summary: `docs/cranelift_gap_analysis.md`
- Active work items: `dot ls` (currently none open)
