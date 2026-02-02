---
title: Add dot-product ISLE patterns
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.940571+01:00"
blocks:
  - hoist-exceptions-runtime-d1afab88
---

Context: src/backends/aarch64/isle_helpers.zig (vector ops) + ISLE rules; cause: dot product patterns pending; fix: add ISLE patterns + lowering tests; deps: none; verification: add vector dot-product tests + zig build test
