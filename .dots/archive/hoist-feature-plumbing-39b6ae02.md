---
title: Feature plumbing
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.679725+01:00\""
closed-at: "2026-02-05T20:05:49.953918+01:00"
close-reason: Thread target features into lowering contexts
blocks:
  - hoist-aarch64-detect-1c4e9c2c
---

File: src/machinst/backend.zig:215; cause: feature flags not wired into ISA selection; fix: thread Features into backend/emit decisions; why: correct encodings.
