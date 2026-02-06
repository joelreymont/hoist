---
title: Exceptions/runtime
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.933678+01:00"
blocks:
  - hoist-resolve-inliner-callees-9f0092f5
---

Context: src/backends/aarch64/isle_helpers.zig, isle_impl.zig, probestack.zig; cause: TODOs for landing pads/vmctx/probestack loop; fix: wire runtime-specific pieces; deps: none; verification: add tests + zig build test
