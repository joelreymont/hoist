---
title: Handle multi-result constructors
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:10:23.179281+01:00\""
closed-at: "2026-01-26T11:34:26.285601+01:00"
---

File: src/dsl/isle/codegen/constructors.zig
Add support for constructors returning tuples:
- Check if ret_ty is tuple type
- Destructure result into multiple bindings
- Track binding IDs for each tuple element
Deps: hoist-emit-constructor-calls-01796f69
Verify: multi-result .isle terms compile
