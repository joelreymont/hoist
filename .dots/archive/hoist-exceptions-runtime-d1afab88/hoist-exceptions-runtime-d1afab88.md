---
title: Exceptions/runtime
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.933678+01:00\""
closed-at: "2026-02-06T10:22:08.314407+01:00"
close-reason: vmctx pinned parity and try_call edge/LSDA coverage completed
blocks:
  - hoist-resolve-inliner-callees-9f0092f5
---

Context: src/backends/aarch64/isle_helpers.zig, isle_impl.zig, probestack.zig; cause: TODOs for landing pads/vmctx/probestack loop; fix: wire runtime-specific pieces; deps: none; verification: add tests + zig build test
