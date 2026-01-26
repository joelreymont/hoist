---
title: Emit extractor calls in patterns
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:10:28.560058+01:00\""
closed-at: "2026-01-26T11:32:49.722253+01:00"
---

File: src/dsl/isle/codegen/constructors.zig
Add emitBinding case for Binding.extractor:
- Call extractor function with source binding
- Handle optional result (extractors can fail)
- Generate guard condition
Deps: hoist-emit-match-arms-34d65f14
Verify: extractors in .isle compile
