---
title: Const phi pass
status: open
priority: 2
issue-type: task
created-at: "2026-01-17T12:46:36.977647+02:00"
---

Files: src/codegen/compile.zig:733-738, src/ir/dfg.zig (block params), src/ir/value_list.zig. Cause: removeConstantPhis stubbed. Fix: implement removal of block params with identical incoming values and alias results; update dfg aliases. Why: eliminate dead phis, align with pipeline. Verify: add unit test for constant phi removal.
