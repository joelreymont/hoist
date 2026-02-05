---
title: VMCTX reg
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.630604+01:00\""
closed-at: "2026-02-05T22:01:29.863930+01:00"
close-reason: vmctx register is computed from ABI arg locations and covered by unit test
blocks:
  - hoist-tls-vmctx-954d6fb6
---

File: src/backends/aarch64/isle_impl.zig:1352; cause: TODO get vmctx register from ABI; fix: plumb vmctx register through ABI/context; why: TLS base access.
