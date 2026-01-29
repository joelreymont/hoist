---
title: Fix JIT defineFunction Allocation
status: active
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.330263+01:00\""
---

Context: src/jit/module.zig:192; cause: writes at mem.ptr+len; fix: allocate via Mem alloc API and write via Mem.write; deps: hoist-add-jit-mem-8953b75c; verification: e2e_jit multi-blob test
