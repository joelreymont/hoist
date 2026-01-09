---
title: Implement alias analysis optimization pass
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T06:47:54.382977+02:00"
---

HIGH: Add memory alias analysis for better optimization of loads/stores. Files: (1) src/codegen/opts/alias.zig - implement basic alias analysis using points-to sets, (2) integrate with GVN and LICM to enable redundant load elimination and load hoisting. Large effort, significant performance impact. Depends on: dominance tree, memory SSA or def-use chains.
