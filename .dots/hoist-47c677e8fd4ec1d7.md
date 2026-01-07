---
title: Replace lower.zig stub types with real IR types
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T08:33:21.118554+02:00"
closed-at: "2026-01-07T08:38:23.568460+02:00"
---

File: src/machinst/lower.zig:8-60. Replace stub types (Function, Block, Inst, Value) with imports from root IR. Change: (1) Remove stub structs, (2) Import: Function from ir.function, Block/Inst/Value from ir.entities, (3) Update LowerCtx to use ir.Function (has .dfg, .layout), (4) Keep type aliases for compatibility. ~20 line change. Enables accessing instruction data in lowering.
