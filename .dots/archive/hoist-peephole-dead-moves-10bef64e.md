---
title: Peephole dead moves
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.764474+01:00\""
closed-at: "2026-02-06T00:02:48.185157+01:00"
close-reason: Dead move elimination implemented and covered by tests
blocks:
  - hoist-peephole-store-pairs-90328735
---

Context: src/codegen/peephole.zig:121-128; cause: dead move elimination not implemented; fix: remove redundant mov_rr; deps: none; verification: zig build test
