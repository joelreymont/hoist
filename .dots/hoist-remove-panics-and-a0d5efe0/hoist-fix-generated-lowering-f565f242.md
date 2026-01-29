---
title: Fix Generated Lowering Panic
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.564289+01:00"
---

Context: src/generated/aarch64_lower_generated.zig:2651; cause: panic on missing metadata; fix: return error and surface to caller; deps: hoist-remove-panics-and-a0d5efe0; verification: isle lower tests
