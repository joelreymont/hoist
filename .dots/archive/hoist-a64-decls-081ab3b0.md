---
title: A64 decls
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:54:46.682594+01:00\\\"\""
closed-at: "2026-02-03T11:15:01.739757+01:00"
close-reason: Added missing aarch64_* decls for lowering rules
blocks:
  - hoist-wire-prelude-5c69866d
---

File: src/backends/aarch64/lower.isle:1; cause: aarch64_* term decls missing for lower rules; fix: add decls with correct signatures for aarch64-specific ops; why: AArch64 ISLE lowering must typecheck.
