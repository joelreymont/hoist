---
title: AArch64 detect
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.672943+01:00\""
closed-at: "2026-02-05T19:52:26.198095+01:00"
close-reason: Implemented OS-specific AArch64 feature detection
blocks:
  - hoist-feature-detect-7a88da07
---

File: src/backends/aarch64/isa.zig:57; cause: detectNative returns defaults; fix: implement OS-specific CPU feature probing; why: enable correct instructions.
