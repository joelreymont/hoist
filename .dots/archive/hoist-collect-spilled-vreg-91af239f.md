---
title: Collect spilled vreg uses per block
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T08:33:53.576379+01:00\""
closed-at: "2026-01-29T09:00:57.716791+01:00"
---

Build map of which blocks use each spilled vreg.
- File: src/codegen/compile.zig:610-617
- Before reload loop: scan vcode blocks for spilled vreg uses
- Build: AutoHashMap(VReg, ArrayList(BlockIdx))
- Depends: hoist-add-block-level-3e897eae
- Verify: zig build test
