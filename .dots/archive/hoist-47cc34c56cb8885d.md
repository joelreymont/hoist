---
title: Verify stack operations work
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:04.518086+02:00"
closed-at: "2026-01-07T15:36:34.731564+02:00"
---

TESTING not implementation (oracle correction). Test existing aarch64_stack_addr (isle_helpers.zig:2467), stack_load, and stack_store. Verify small immediate handling. Verify large offset handling (multi-instruction). Test: Load/store values to/from various stack slots. Depends on dot 1.0. Phase 1.1, Priority P0
