---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:43:27.141668+02:00"
closed-at: "2026-01-01T09:05:17.943012+02:00"
close-reason: Replaced with correctly titled task
---

Port IR builder from cranelift/codegen/src/ir/builder.rs (~500 LOC). Create src/ir/builder.zig with FunctionBuilder for constructing IR (insert blocks, instructions, control flow). Depends on: function (hoist-474de8b519abfca8), dfg (hoist-474de80e66ee3f4d), instructions (hoist-474de7b914dd155d). Files: src/ir/builder.zig, builder_test.zig. Ergonomic IR construction API.
