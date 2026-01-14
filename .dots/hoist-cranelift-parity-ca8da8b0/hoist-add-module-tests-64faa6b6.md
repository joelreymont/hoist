---
title: Add module tests
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.659303+02:00"
---

Files: src/backends/aarch64/jit_harness.zig:139-223
Root cause: no module-level integration tests.
Fix: add tests for multi-function modules and data linking.
Why: regression coverage for module API.
Deps: Add module api, Add jit module, Add object module.
Verify: zig build test.
