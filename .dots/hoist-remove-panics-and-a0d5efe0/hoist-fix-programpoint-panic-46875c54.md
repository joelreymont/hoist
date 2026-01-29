---
title: Fix ProgramPoint Panic
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.542284+01:00\\\"\""
closed-at: "2026-01-29T10:32:18.942134+01:00"
close-reason: done
---

Context: src/ir/progpoint.zig:25; cause: unwrapInst panics; fix: return error or optional and update call sites; deps: hoist-remove-panics-and-a0d5efe0; verification: ir tests
