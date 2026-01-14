---
title: Emit x64 simd
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.371880+02:00"
---

Files: src/backends/x64/emit.zig:11-30
Root cause: SIMD encoding is missing.
Fix: add VEX/EVEX prefixes and opcode maps for SIMD insts.
Why: SIMD support.
Deps: Add x64 simd.
Verify: SIMD encoding tests.
