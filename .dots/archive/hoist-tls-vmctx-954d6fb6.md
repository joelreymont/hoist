---
title: TLS vmctx
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.623336+01:00\""
closed-at: "2026-02-05T22:09:46.314993+01:00"
close-reason: Added TLS constructor + trap sequencing tests and verified full test suite
blocks:
  - hoist-add-mach-o-b3d199a0
---

File: src/backends/aarch64/isle_impl.zig:1352; cause: vmctx register TODO and TLS helpers incomplete; fix: wire vmctx from ABI and complete TLS bounds/traps; why: correct TLS loads.
