# AArch64 Opcode Parity Report

Date: 2026-02-05
Scope: PLAN section 8 (`/Users/joel/Work/hoist/PLAN.md`)

## Summary

- Section-8 opcode parity items are implemented and covered.
- No unresolved opcode checks remain in section 8.
- New section-8 dots should only be created on reproduced failing parity cases.

## Evidence Matrix

| Area | Status | Dot Evidence | Test/Code Evidence |
|---|---|---|---|
| `istore8` | complete | `.dots/archive/hoist-verify-istore8-lowering-ecbda1cb.md` | `tests/isle_memory.zig`, `src/backends/aarch64/lower_test.zig` |
| `istore16` | complete | `.dots/archive/hoist-verify-istore16-lowering-5161cfef.md` | `tests/isle_memory.zig`, `src/backends/aarch64/lower_test.zig` |
| `istore32` | complete | `.dots/archive/hoist-verify-istore32-lowering-6d9179e9.md` | `tests/isle_memory.zig`, `src/backends/aarch64/lower_test.zig` |
| `uload8x8/sload8x8` | complete | `.dots/archive/hoist-verify-simd-widen-b421e77a.md` | `tests/isle_memory.zig` |
| `uload16x4/sload16x4` | complete | `.dots/archive/hoist-verify-simd-widen-b421e77a.md` | `tests/isle_memory.zig` |
| `uload32x2/sload32x2` | complete | `.dots/archive/hoist-verify-simd-widen-b421e77a.md` | `tests/isle_memory.zig` |
| `uadd_overflow_cin/sadd_overflow_cin` | complete | `.dots/archive/hoist-verify-carry-in-2e75992f.md` | `src/codegen/compile.zig` tests for ADCS lowering |
| `usub_overflow_bin/ssub_overflow_bin` | complete | `.dots/archive/hoist-verify-carry-in-2e75992f.md` | `src/codegen/compile.zig` tests for SBCS lowering |
| `iadd_imm` | complete | `.dots/archive/hoist-47b24cff83e241b8.md` | `tests/e2e_jit.zig`, `src/backends/aarch64/lower.isle` |
| `irsub_imm` | complete | `.dots/archive/hoist-47b24cff91e9e2df.md` | `src/backends/aarch64/lower.isle` |
| `imul_imm` | complete | `.dots/archive/hoist-47b24cffaf5923e0.md` | `src/backends/aarch64/lower.isle` |
| `try_call/try_call_indirect` semantics | complete | `.dots/archive/hoist-compile-try-call-04ba9ee1.md` | `tests/e2e_jit.zig`, `src/backends/aarch64/lower_test.zig`, `src/ir/flowgraph.zig`, exception-edge walk in `src/codegen/compile.zig` |

## Decision

- Section-8 parity is reconciled and closed.
- Keep monitoring via existing parity stages and test suite.
