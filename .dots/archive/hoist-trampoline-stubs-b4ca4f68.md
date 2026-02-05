---
title: Trampoline stubs
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.658300+01:00\""
closed-at: "2026-02-05T22:43:26.004727+01:00"
close-reason: Wire branch26 veneer emission into MachBuffer finalize
blocks:
  - hoist-label-map-c6fbce16
---

File: src/machinst/stubs.zig:127; cause: stubs exist but not wired into emit; fix: integrate veneer/trampoline emission for far branches; why: reachability.
