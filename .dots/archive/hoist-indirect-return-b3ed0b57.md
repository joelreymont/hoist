---
title: Indirect return
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.707631+01:00\""
closed-at: "2026-02-05T20:37:20.355411+01:00"
close-reason: Enable sret lowering and test
blocks:
  - hoist-return-marshal-8237ef3b
---

File: build.zig:285; cause: aarch64_indirect_return gated by struct type support; fix: finish sret path and enable test; why: aggregate returns.
