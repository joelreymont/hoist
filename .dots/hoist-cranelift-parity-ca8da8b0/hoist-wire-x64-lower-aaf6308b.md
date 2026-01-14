---
title: Wire x64 lower
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.331109+02:00"
---

Files: src/backends/x64/lower.zig:12-55
Root cause: lowerInst/lowerBranch stubs return false.
Fix: integrate generated x64_lower and route inst/branch lowering through it.
Why: enable IR->x64 lowering.
Deps: Extend x64 isle, Extend x64 fp.
Verify: add lower integration tests.
