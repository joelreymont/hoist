---
title: Add tail call stack copy
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:51:32.739774+02:00"
---

In src/backends/aarch64/isle_helpers.zig:3217-3223, implement stack arg copying for tail calls. Use Cranelift's overlap-safe algorithm. Deps: none. Verify: zig build test
