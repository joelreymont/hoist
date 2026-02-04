---
title: ISLE enum args
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-05T01:20:12.531908+01:00\\\"\""
closed-at: "2026-02-05T01:25:45.256019+01:00"
close-reason: Enums passed by value; extern fallback supports ctx.lower_ctx
---

src/dsl/isle/codegen/constructors.zig:842; cause: enum_type treated as ref type (arg: *const IntCC) but call sites pass value; fix: pass enums by value (isRefType false for .enum_type) + update tests; proof: aarch64 generated code compiles; test: zig build test
