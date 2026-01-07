---
title: Implement ABI argument marshaling
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T20:42:58.060352+02:00"
closed-at: "2026-01-05T11:23:26.955382+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:83,113,144 - Three TODO comments for 'Full ABI argument marshaling'. Currently stubs return empty vreg arrays. Need to implement ARM64 calling convention: first 8 args in x0-x7, rest on stack, following AAPCS64.
