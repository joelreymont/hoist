---
title: Add ssa tests
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.711855+02:00"
---

Files: src/ir/ssa_tests.zig:1-120
Root cause: tests cover SSA properties but not builder API.
Fix: add tests for use_var/def_var and block sealing.
Why: prevent SSA regressions.
Deps: Wire ssa builder.
Verify: zig build test.
