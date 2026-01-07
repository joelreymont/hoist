---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:43:11.575804+02:00"
closed-at: "2026-01-01T09:05:17.931891+02:00"
close-reason: Replaced with correctly titled task
---

Port DFG from cranelift/codegen/src/ir/dfg.rs (~1200 LOC). Create src/ir/dfg.zig with DataFlowGraph, value definitions, instruction results, block parameters, constant pool. Depends on: instructions (hoist-474de7b914dd155d), entities (hoist-474de7656791a5b2), entity maps (hoist-474de68d56804654). Files: src/ir/dfg.zig, dfg_test.zig. SSA value tracking.
