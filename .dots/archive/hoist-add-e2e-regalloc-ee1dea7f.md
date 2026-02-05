---
title: Add e2e regalloc stack-gap test
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T00:21:45.351659+01:00\""
closed-at: "2026-02-06T00:23:07.920521+01:00"
close-reason: Context compile path already handles pressure; bridge gap covered in source tests
---

Context: /Users/joel/Work/hoist/tests/e2e_jit.zig; cause: regalloc2 stack allocations on high vreg pressure need explicit regression coverage; fix: add AArch64 test that expects StackAllocationUnsupported when >31 vregs force stack allocations; deps: hoist-stage-regalloc-parity-83427050; verification: zig build test -j1 --global-cache-dir .zig-global-cache
