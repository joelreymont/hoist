---
title: Add x64 alu
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:31:23.486958+02:00\""
closed-at: "2026-01-23T10:04:19.084538+02:00"
---

Files: src/backends/x64/inst.zig:12-93
Root cause: Inst enum is bootstrap and lacks ALU/logic ops.
Fix: add add/sub/and/or/xor/cmp/test variants with reg/imm/mem forms and sizes.
Why: needed to lower integer IR ops on x64.
Deps: none.
Verify: extend inst format tests in src/backends/x64/inst.zig.
