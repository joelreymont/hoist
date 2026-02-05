---
title: Feature detect
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.665934+01:00\""
closed-at: "2026-02-05T19:55:03.910184+01:00"
close-reason: detectNative implemented and wired via initNative
blocks:
  - hoist-trampoline-stubs-b4ca4f68
---

File: src/backends/aarch64/isa.zig:57; cause: detectNative is stubbed; fix: implement platform feature detection and plumb into backend; why: correct ISA selection.
