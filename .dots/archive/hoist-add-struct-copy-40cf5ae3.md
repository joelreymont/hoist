---
title: Add struct copy DMB barriers
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:51:50.625497+02:00\""
closed-at: "2026-01-23T14:52:59.937169+02:00"
---

In src/backends/aarch64/abi.zig:684-769, add DMB ISH barriers around struct copies. Ensure thread safety. Deps: none. Verify: zig build test
