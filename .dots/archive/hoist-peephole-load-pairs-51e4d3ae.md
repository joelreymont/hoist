---
title: Peephole load pairs
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.750032+01:00\\\"\""
closed-at: "2026-02-05T23:31:37.976901+01:00"
close-reason: Added base-clobber safety checks and tests
blocks:
  - hoist-lower-shuffle-b06c30d8
---

Context: src/codegen/peephole.zig:96-101; cause: LDP combining not implemented; fix: implement load-pair combining with safety checks; deps: none; verification: zig build test
