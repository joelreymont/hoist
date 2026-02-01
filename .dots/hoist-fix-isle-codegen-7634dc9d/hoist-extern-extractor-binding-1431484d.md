---
title: Extern extractor binding
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-01T22:29:54.173394+01:00\\\"\""
closed-at: "2026-02-01T22:34:24.928169+01:00"
close-reason: completed
---

Context: src/dsl/isle/codegen/match.zig:372, src/dsl/isle/codegen.zig:100; cause: extern extractor bindings assume ret_ty outputs and lack arg-field access; fix: add match_extractor binding + align extern extractor signatures to return arg struct; why: correct multi-arg extractor patterns and wrappers
