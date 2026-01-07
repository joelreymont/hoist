---
title: Fix ABI test compilation errors
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T17:01:30.237295+02:00\""
closed-at: "2026-01-07T21:59:45.419399+02:00"
---

File: src/backends/aarch64/abi.zig - Multiple compilation errors: bitCast size mismatch at 476, enum coercion at 538, PReg missing 'class' field at 645/657/667, argument count mismatches at 1251/3442/3465/3495. Test files also have errors. Need to fix to get tests passing.
