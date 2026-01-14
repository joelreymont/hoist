---
title: Add x64 tests
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.383556+02:00"
---

Files: src/backends/x64/emit.zig:11-30, src/backends/x64/lower.zig:12-55
Root cause: no x64 encoding/lowering coverage beyond stubs.
Fix: add encoding tests and lowering integration tests.
Why: prevent regressions.
Deps: Emit x64 alu, Emit x64 mem, Emit x64 branch, Emit x64 simd, Emit x64 atom, Wire x64 lower.
Verify: zig build test.
