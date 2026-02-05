---
title: Integrate regalloc2
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.778156+01:00\""
closed-at: "2026-02-06T00:32:43.889847+01:00"
close-reason: Integrated regalloc2 adapter/allocator in machinst compile
blocks:
  - hoist-peephole-redundant-loads-a6b2ed72
---

Context: src/machinst/compile.zig:117-120; cause: compile pipeline uses linear scan only; fix: integrate regalloc2 pipeline and remove TODO path; deps: none; verification: zig build test
