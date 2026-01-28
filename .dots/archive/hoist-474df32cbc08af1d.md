---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:46:18.113041+02:00"
closed-at: "2026-01-01T09:05:34.410124+02:00"
close-reason: Replaced with correctly titled task
---

Port dominator tree from cranelift/codegen/src/dominator_tree.rs (~800 LOC). Create src/analysis/dominance.zig with DominatorTree, immediate dominators, dominator frontiers. Depends on: CFG (hoist-474de862f689af3b), entity (hoist-474de68d56804654). Files: src/analysis/dominance.zig, dominance_test.zig. Required for SSA construction and optimization passes.
