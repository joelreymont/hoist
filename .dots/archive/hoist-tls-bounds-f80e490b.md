---
title: TLS bounds
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.638360+01:00\""
closed-at: "2026-02-05T22:09:46.321071+01:00"
close-reason: Verified trap guard sequencing and TLS helper offset paths with unit tests
blocks:
  - hoist-vmctx-reg-c1d37eef
---

File: src/backends/aarch64/isle_helpers.zig:2204; cause: bounds checking TODO; fix: emit traps/branches for TLS bounds; why: safety/correctness.
