---
title: Add JIT Mem Allocator Cursor
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.325341+01:00\\\"\""
closed-at: "2026-01-29T10:12:54.022773+01:00"
close-reason: done
---

Context: src/jit/memory.zig:1; cause: no allocation tracking; fix: add cursor/alloc API with alignment and bounds checks; deps: hoist-fix-jit-mem-79025e5b; verification: new unit test for alloc/overflow
