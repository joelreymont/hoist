---
title: Verify AArch64 imm arithmetic lowering
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T09:28:44.722115+01:00\\\"\""
closed-at: "2026-02-06T09:45:49.793865+01:00"
close-reason: Added immediate-lowering and ISLE coverage tests; verified with zig build test.
---

Context: src/backends/aarch64/lower.isle:1778,1807,560 and tests/isle_coverage.zig; cause: parity plan requires verified iadd_imm/irsub_imm/imul_imm lowering; fix: add/adjust lowering tests to assert ISLE constructor coverage and codegen success; deps: hoist-exec-aarch64-parity-da78c5c3; verification: zig build test -j1 --global-cache-dir .zig-global-cache
