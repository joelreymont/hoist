---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:43:22.500536+02:00"
closed-at: "2026-01-01T09:05:17.939256+02:00"
close-reason: Replaced with correctly titled task
---

Port Function from cranelift/codegen/src/ir/function.rs (~800 LOC). Create src/ir/function.zig with Function struct combining DFG, layout, signatures, stack slots, global values. Depends on: dfg (hoist-474de80e66ee3f4d), layout (hoist-474de862f689af3b), entities (hoist-474de7656791a5b2). Files: src/ir/function.zig, function_test.zig. Complete IR function container.
