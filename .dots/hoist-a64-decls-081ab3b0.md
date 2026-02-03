---
title: A64 decls
status: open
priority: 1
issue-type: task
created-at: "2026-02-02T23:54:46.682594+01:00"
blocks:
  - hoist-wire-prelude-5c69866d
---

File: src/backends/aarch64/lower.isle:1; cause: aarch64_* term decls missing for lower rules; fix: add decls with correct signatures for aarch64-specific ops; why: AArch64 ISLE lowering must typecheck.
