---
title: Add istore16/32 lowering tests
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T10:22:45.214312+01:00\""
closed-at: "2026-02-06T10:25:39.270541+01:00"
close-reason: Added STRH and 32-bit STR regression checks
---

src/codegen/compile.zig:test section near istore8; add AArch64 regression tests ensuring istore16 lowers to STRH and istore32 lowers to STR (32-bit). Depends on hoist-backend-parity-cfd28858.
