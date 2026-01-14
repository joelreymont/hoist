---
title: Add x64 mem
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.301350+02:00"
---

Files: src/backends/x64/inst.zig:12-93, src/backends/x64/inst.zig:201-236
Root cause: no memory operand type or load/store insts.
Fix: add Mem operand (base/index/scale/disp) and load/store/lea inst variants.
Why: load/store lowering needs address modes.
Deps: none.
Verify: extend inst format tests in src/backends/x64/inst.zig.
