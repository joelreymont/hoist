---
title: Add x64 simd
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.313662+02:00"
---

Files: src/backends/x64/inst.zig:12-93
Root cause: SIMD inst variants are missing.
Fix: add SSE2/AVX move, arithmetic, compare, shuffle variants needed for Wasm SIMD.
Why: parity with Cranelift SIMD support.
Deps: Add x64 mem.
Verify: extend inst format tests in src/backends/x64/inst.zig.
