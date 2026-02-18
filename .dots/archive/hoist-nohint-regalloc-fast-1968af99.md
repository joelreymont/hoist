---
title: nohint regalloc fast
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-18T10:52:50.254378+01:00\\\"\""
closed-at: "2026-02-18T10:56:51.235133+01:00"
close-reason: "discarded: mixed-only gain and large regressions"
---

file:src/regalloc/linear_scan.zig:343-521; cause: tryAllocateReg does per-range coalesce/hint hash lookups even when hints/coalesce maps are empty (common no-opt path); fix: add no-hint fast path in allocateInto/tryAllocateReg to skip those lookups; why: reduce regalloc hot-loop overhead in single-thread compile.
