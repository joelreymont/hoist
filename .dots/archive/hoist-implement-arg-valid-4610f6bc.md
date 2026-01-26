---
title: Implement arg validation in constructors
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:10:34.581742+01:00\""
closed-at: "2026-01-26T11:34:26.291178+01:00"
---

File: src/dsl/isle/codegen/constructors.zig:179
Replace TODO in emitArgValidation:
- Check arg types match term signature
- Generate debug assertions if enabled
- Validate ref vs value passing
Deps: hoist-emit-match-arms-34d65f14
Verify: type errors caught at compile time
