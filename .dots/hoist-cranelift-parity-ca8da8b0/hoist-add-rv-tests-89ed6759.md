---
title: Add rv tests
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.447821+02:00"
---

Files: tests (new), src/backends/riscv64/emit.zig (new)
Root cause: no riscv64 encoding/lowering tests.
Fix: add encoding + lowering tests for RV64I/F/A.
Why: parity and regression coverage.
Deps: Emit rv base, Emit rv fp, Wire rv lower.
Verify: zig build test.
