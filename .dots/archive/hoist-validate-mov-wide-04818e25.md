---
title: Validate MOV wide shift encoding
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T22:16:02.207998+01:00\""
closed-at: "2026-02-06T22:18:19.592803+01:00"
close-reason: Added strict shift validation for movz/movk/movn and regression tests
---

src/backends/aarch64/emit.zig: emitMovz/emitMovk/emitMovn derive hw via shift/16 without validating shift granularity/range. Add explicit InvalidShift checks (multiple of 16, 32-bit <=16, 64-bit <=48) and regression tests. Depends on hoist-validate-add-sub-cdd38716. Est: 20m
