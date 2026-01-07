---
title: Add simple arithmetic e2e test
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:34:01.470759+02:00"
closed-at: "2026-01-07T08:13:25.038058+02:00"
---

File: src/backends/aarch64/e2e_arithmetic_test.zig (new). Test basic arithmetic: iadd, isub, imul, udiv, sdiv. Build IR: func(a, b) { return a + b; }, compile, execute with test values, verify results. Test all integer widths (I8, I16, I32, I64). Test overflow behavior. ~90 lines. Depends: pipeline (hoist-47c5a1d26d09f085).
