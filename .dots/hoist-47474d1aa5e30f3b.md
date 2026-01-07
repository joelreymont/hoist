---
title: Port regalloc2 register allocator
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T00:50:22.106091+02:00\""
closed-at: "\"2026-01-01T04:11:23.579228+02:00\""
blocks:
  - hoist-47474d1a87c352c2
---

Crate: regalloc2 (~10k LOC dense Rust). Linear scan + backtracking allocator. Most correctness-critical component. Options: full port or simplified version. Fuzzing essential.
