---
title: Lower isplit, iconcat
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:11:33.477947+02:00"
closed-at: "2026-01-07T10:09:45.926901+02:00"
---

File: src/generated/aarch64_lower_generated.zig add patterns
Opcodes: isplit (I128→I64,I64), iconcat (I64,I64→I128)
Implementation: isplit - extract low/high 64 bits (~40 lines), iconcat - combine two 64-bit values (~40 lines)
Dependencies: None
Estimated: 1 day
Test: Test I128 split/concat
