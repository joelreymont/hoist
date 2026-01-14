---
title: Add interp simd
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.863620+02:00"
---

Files: src/interpreter/interpreter.zig (new)
Root cause: interpreter lacks SIMD ops.
Fix: implement vector ops needed for Wasm SIMD.
Why: SIMD parity and diff testing.
Deps: Add ir interp.
Verify: SIMD interpreter tests.
