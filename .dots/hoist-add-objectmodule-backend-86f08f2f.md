---
title: Add ObjectModule backend
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:51:13.891051+02:00"
---

Create src/module/object.zig for AOT object file emission. Match cranelift-object. Deps: Add symbol table to Module. Verify: zig build test
