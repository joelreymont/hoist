---
title: Incremental liveness ranges
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T15:08:52.330329+01:00\\\"\""
closed-at: "2026-02-17T15:09:08.335704+01:00"
close-reason: "Completed: incremental in-place liveness range construction; A/B positive improvements recorded in /tmp/hoist-inc-ab.md; test and bench-gate passed."
---

Full context: src/regalloc/liveness.zig built single-block ranges via temporary hash map and second conversion pass; cause was extra allocations/hash iteration and unsorted range emission forcing additional sort costs; fix by building ranges incrementally in-place with direct vreg->range index updates and marking sorted output for allocator fast path; proof via A/B /tmp/hoist-inc-ab.md and verification with zig build test + zig build bench-gate.
