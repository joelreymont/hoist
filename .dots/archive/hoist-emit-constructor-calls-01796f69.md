---
title: Emit constructor calls in patterns
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:10:17.786805+01:00\""
closed-at: "2026-01-26T11:32:49.716794+01:00"
---

File: src/dsl/isle/codegen/constructors.zig
Add emitBinding case for Binding.constructor:
- Check fallibility (impure -> optional result)
- Emit 'if (result) |v|' for fallible
- Chain multiple constructors with early return
Deps: hoist-emit-match-arms-34d65f14
Verify: generated code compiles
