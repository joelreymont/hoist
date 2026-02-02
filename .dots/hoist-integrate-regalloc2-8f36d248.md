---
title: Integrate regalloc2
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.778156+01:00"
blocks:
  - hoist-peephole-redundant-loads-a6b2ed72
---

Context: src/machinst/compile.zig:117-120; cause: compile pipeline uses linear scan only; fix: integrate regalloc2 pipeline and remove TODO path; deps: none; verification: zig build test
