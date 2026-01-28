---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:46:00.324222+02:00"
closed-at: "2026-01-01T09:05:26.890920+02:00"
close-reason: Replaced with correctly titled task
---

Port Context from cranelift/codegen/src/context.rs (~600 LOC). Create src/context.zig with Context struct, compile() entry point, optimization pipeline orchestration. Depends on: IR function (hoist-474de8b519abfca8), optimization passes (hoist-474df1c5a313fd16), compile pipeline (hoist-474ded305f087ca7). Files: src/context.zig, context_test.zig. Top-level API: Context.compile(func, isa) → machine code. MILESTONE: End-to-end compilation!
