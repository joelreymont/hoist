---
title: Fix JIT defineData Allocation
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.334970+01:00\\\"\""
closed-at: "2026-01-29T10:14:53.719055+01:00"
close-reason: done
---

Context: src/jit/module.zig:209; cause: data blobs overlap and skip I-cache flush; fix: allocate via Mem alloc API and zero/copy via Mem.write; deps: hoist-add-jit-mem-8953b75c; verification: e2e_jit data relocation test
