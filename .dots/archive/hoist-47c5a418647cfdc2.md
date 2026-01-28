---
title: Add vector arithmetic e2e test
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:34:07.455371+02:00"
closed-at: "2026-01-07T08:13:25.422765+02:00"
---

File: src/backends/aarch64/e2e_vector_test.zig (new). Test SIMD vector ops: iadd (I32X4), fadd (F32X4), splat, extractlane. Build IR with vector operations, compile to NEON instructions (ADD.4S, FADD.4S, DUP, UMOV). Execute, verify lane values. Test vector loads/stores. ~120 lines. Depends: pipeline (hoist-47c5a1d26d09f085).
