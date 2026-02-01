---
title: Fix Generated Lowering Panic
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.564289+01:00\""
closed-at: "2026-02-01T20:44:44.726522+01:00"
close-reason: "completed: no panic in generated lowering; rules return errors/false (src/generated/aarch64_lower_generated.zig)"
---

Context: src/generated/aarch64_lower_generated.zig:2651; cause: panic on missing metadata; fix: return error and surface to caller; deps: hoist-remove-panics-and-a0d5efe0; verification: isle lower tests
