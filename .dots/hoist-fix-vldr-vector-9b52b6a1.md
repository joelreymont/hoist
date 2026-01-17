---
title: Fix vldr vector size
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:54:35.294606+02:00"
---

In src/backends/aarch64/isle_impl.zig:2933, handle 32-bit and other vector sizes in vldr. Remove @panic. Deps: Add I8X4 vector type. Verify: zig build test
