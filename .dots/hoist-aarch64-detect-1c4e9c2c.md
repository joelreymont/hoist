---
title: AArch64 detect
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.672943+01:00"
blocks:
  - hoist-feature-detect-7a88da07
---

File: src/backends/aarch64/isa.zig:57; cause: detectNative returns defaults; fix: implement OS-specific CPU feature probing; why: enable correct instructions.
