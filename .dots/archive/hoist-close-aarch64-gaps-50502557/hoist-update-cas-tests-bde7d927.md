---
title: Update cas tests
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T14:45:37.711072+02:00\""
closed-at: "2026-01-14T14:49:31.127288+02:00"
close-reason: align with assembler encodings
---

File: src/backends/aarch64/emit.zig:11547. Root cause: CAS expected constants do not match assembler encodings for cas/casa/casl/casal with r0/r1/r2; tests assume swapped fields. Fix: update expected constants/comments to match actual encoding (e.g., cas w0,w1,[x2] -> 0x88A07C41). Verify: zig build test --cache-dir /tmp/hoist-zig-cache --global-cache-dir /tmp/hoist-zig-global.
