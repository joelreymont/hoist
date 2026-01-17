# Code Review Report

Date: 2026-01-17

## Critical
1. Default target x86_64 fails to compile
   - File: `src/context.zig:34-37`, `src/codegen/compile.zig:978-983`, `src/codegen/compile.zig:4722-4725`
   - Issue: `Context` defaults to x86_64 but x86_64 lowering is stubbed.
   - Impact: `compileFunction` fails by default.
   - Fix: default to supported arch or return explicit error for unsupported arch; gate lowering on supported backends.

## High
1. No stage-level IR dump hooks
   - File: `src/codegen/context.zig:32-36`, `src/ir/function.zig:114-122`
   - Issue: no per-stage IR dump support; only final disasm optional.
   - Impact: hard to debug pipeline stages.
   - Fix: add IR printer + context debug hooks per stage.

2. zcheck properties not wired into test runner
   - File: `src/root.zig:126-134`, `src/backends/aarch64/zcheck_properties.zig:1`
   - Impact: property tests not executed in `zig build test`.
   - Fix: import zcheck properties in root tests or add dedicated test step.

3. Large test suites commented out
   - File: `build.zig:100-379`
   - Issue: multiple E2E and coverage tests disabled due to API drift.
   - Impact: regressions slip; weak integration coverage.
   - Fix: update tests to current APIs and re-enable.

## Medium
1. Duplicate `Ranges` implementations
   - File: `src/foundation/ranges.zig` and `src/codegen/ranges.zig`
   - Impact: DRY violation, divergent fixes.
   - Fix: consolidate to one module and update imports.

2. Duplicate `.isub` lowering block
   - File: `src/codegen/compile.zig:1726-1785`
   - Impact: unreachable duplicate code.
   - Fix: remove duplication and/or factor helper.

3. `iconst` lowering is highly duplicated
   - File: `src/codegen/compile.zig:1311-1631`
   - Impact: error-prone and hard to maintain.
   - Fix: extract immediate-construction helper.

4. Runtime feature detection is stubbed
   - File: `src/target/features.zig:83-88`
   - Impact: no CPU feature detection; perf and correctness risks on heterogeneous CPUs.
   - Fix: implement OS-specific detection (x86 CPUID, aarch64 HWCAP/sysctl), parse and expose flags.

5. `removeConstantPhis` is stubbed
   - File: `src/codegen/compile.zig:733-738`
   - Impact: missed optimization and dead pass in pipeline.
   - Fix: implement or remove from pipeline until block params land.

## Low
1. Snapshot testing claim not used in encoding tests
   - File: `src/backends/aarch64/encoding_test.zig:1-5`
   - Impact: missed structured snapshots.
   - Fix: add ohsnap-based snapshots for IR dumps and/or encoding output.

## Baseline Tests (before fixes)
- `zig build test` failed (13 tests).
- Failures included: AArch64 ABI tests, inst formatting tests, SCCP, IR builder, liveness.

