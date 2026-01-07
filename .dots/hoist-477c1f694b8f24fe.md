---
title: Implement iconcat MVP (I128 concatenation)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T15:51:28.775066+02:00"
closed-at: "2026-01-03T15:52:53.742276+02:00"
---

Files: src/backends/aarch64/lower.isle (add type/decls/rules), src/backends/aarch64/isle_helpers.zig (add constructor). Investigation showed infrastructure exists - just need ISLE glue. Steps: (1) Add 'type ValueRegs extern' to lower.isle after line 675. (2) Add 'decl value_regs_from_values' + extern constructor to lower.isle ~line 778. (3) Implement value_regs_from_values() in isle_helpers.zig - takes two I64 Values, calls ctx.getValueRegs(), extracts single VRegs, returns ValueRegs.two(). (4) Add iconcat lowering rule: (rule (lower (has_type $I128 (iconcat lo hi))) (value_regs_from_values lo hi)). Total: ~35 LOC. Accept: iconcat lowers to ValueRegs pair, builds without errors. NOTE: isplit deferred - needs multi-result return design.
