---
title: Fix JIT Memory
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.320523+01:00\""
closed-at: "2026-01-29T10:30:14.318817+01:00"
close-reason: done
---

Context: src/jit/module.zig:192; cause: JIT writes at mem.ptr+len without tracking or bounds and skips I-cache flush; fix: implement allocator cursor + use Mem.write; deps: hoist-plan-review-fixes-af4c6e65; verification: e2e_jit tests + zcheck
