---
title: hoist-skip-noopt-coalesce
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T10:13:14.842979+01:00\\\"\""
closed-at: "2026-02-18T10:21:34.786845+01:00"
close-reason: "completed: immediate repeat-9 A/B reruns show sustained gains with zero regressions"
---

src/codegen/compile.zig allocateRegisters always calls collectCoalescePairs even when target.optimize=false; skip coalesce pair collection on no-opt path to remove extra full VCode scan and hint bookkeeping, then gate with immediate repeat-9 A/B
