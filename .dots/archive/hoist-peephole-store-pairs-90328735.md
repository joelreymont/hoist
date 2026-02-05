---
title: Peephole store pairs
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.757355+01:00\\\"\""
closed-at: "2026-02-05T23:33:35.423777+01:00"
close-reason: Added store-pair safety and skip-case tests
blocks:
  - hoist-peephole-load-pairs-51e4d3ae
---

Context: src/codegen/peephole.zig:114-118; cause: STP combining not implemented; fix: implement store-pair combining with safety checks; deps: none; verification: zig build test
