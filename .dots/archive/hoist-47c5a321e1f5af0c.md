---
title: Add callee-save preservation e2e test
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:33:51.300100+02:00"
closed-at: "2026-01-07T08:13:24.258734+02:00"
---

File: src/backends/aarch64/e2e_callee_saves_test.zig (new). Test callee-save registers preserved across call: X19-X28, V8-V15. Build IR: (1) initialize callee-saves, (2) call function, (3) verify values unchanged. Use inline asm to set/check registers. Verify prologue STR, epilogue LDR of callee-saves. ~100 lines. Depends: pipeline (hoist-47c5a1d26d09f085).
