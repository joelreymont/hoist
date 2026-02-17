---
title: Pick safe scratch reg
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T10:38:33.810784+01:00\""
closed-at: "2026-02-17T10:38:33.838471+01:00"
close-reason: completed in jj commit 52a99349 with passing test, integration, jit, fuzz
---

File: /Users/joel/Work/hoist/src/codegen/compile.zig:6613,7706. Cause: fixed scratch reg can conflict with move endpoints. Fix: pickPhiScratchReg chooses conflict-free caller-saved register and tests cover chosen/null cases. Why: avoid TempConflict and preserve correctness.
