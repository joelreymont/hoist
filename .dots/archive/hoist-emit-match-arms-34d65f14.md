---
title: Emit match arms from DecisionTree
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:10:11.852122+01:00\""
closed-at: "2026-01-26T11:32:49.710872+01:00"
---

File: src/dsl/isle/codegen/constructors.zig:107
Replace emitRulesetBody TODO with tree traversal:
- Walk DecisionTree.root
- Emit switch/if for each Decision
- Generate bindings for match_variant
Deps: hoist-add-decision-tree-33b3eb46
Verify: generated code compiles
