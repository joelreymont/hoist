---
title: Fix CodegenResult Panics
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.553598+01:00"
---

Context: src/codegen/error.zig:125; cause: unwrap/unwrapErr panics; fix: remove or replace with error-returning APIs; deps: hoist-remove-panics-and-a0d5efe0; verification: codegen tests
