---
title: Add x64 branch
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.307948+02:00\""
closed-at: "2026-01-23T10:05:48.107474+02:00"
---

Files: src/backends/x64/inst.zig:53-70, src/backends/x64/inst.zig:160-236
Root cause: minimal branch/call coverage.
Fix: add cmp/test, setcc, cmov, call_indirect, ret_imm variants and richer branch targets.
Why: correct control flow and ABI lowering.
Deps: Add x64 alu, Add x64 mem.
Verify: extend inst format tests in src/backends/x64/inst.zig.
