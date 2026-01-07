---
title: Retarget ISLE codegen to emit Zig
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T00:50:22.109509+02:00\""
closed-at: "\"2026-01-01T06:33:24.947858+02:00\""
close-reason: "\"ISLE→Zig codegen transformation complete (941→818 LOC). All Rust→Zig transformations done: pragmas, pointers, enums, traits, patterns, expressions, generics, method names.\""
blocks:
  - hoist-47474d1a87c352c2
---

File: ../wasmtime/cranelift/isle/isle/src/codegen.rs (~900 LOC). Modify to emit Zig instead of Rust. match->switch, Option->?T, trait methods->comptime. Preserves 27k LOC of tested ISLE rules.
