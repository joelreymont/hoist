---
title: Rewrite pass removal
status: closed
priority: 3
issue-type: task
created-at: "\"2026-02-17T18:21:36.882409+01:00\""
closed-at: "2026-02-17T18:39:02.883116+01:00"
close-reason: discarded (perf regressions)
---

Full context: rewrite stage in src/codegen/compile.zig still costs measurable time on large functions. Cause: full instruction rewrite pass after regalloc. Fix: fold mapping into emit path and eliminate standalone rewrite where safe, preserving correctness.
