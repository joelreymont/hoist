---
title: Reconcile CFG types
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:05:35.714345+02:00\""
closed-at: "2026-01-24T00:09:22.706513+02:00"
---

Files: src/codegen/optimize.zig:168, src/ir/cfg.zig
What: Unify the two CFG representations blocking LICM
Currently: optimize.zig uses different CFG than main pipeline
Fix: Standardize on one CFG type, update all users
Deps: Blocks LICM implementation
Verification: LICM pass runs without CFG conversion
