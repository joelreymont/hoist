---
title: Add probestack libcall sig
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:50:24.674931+02:00"
---

In src/ir/libcall.zig:160-162, implement probestack signature. Takes stack size, returns void. Match Cranelift's sig. Deps: none. Verify: zig build test
