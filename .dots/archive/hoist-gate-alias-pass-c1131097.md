---
title: Gate alias pass by complexity
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T16:13:48.930678+01:00\""
closed-at: "2026-02-17T16:18:07.472158+01:00"
close-reason: "done: gated alias analysis by complexity>=160; A/B wins: large100 +12.03%, memory +9.52%, mixed +7.69% with no regressions (/tmp/hoist-aliascomp-ab.md)"
---

src/codegen/compile.zig optimize(): run alias analysis only when complexity is high enough; skip for small functions to reduce compile latency. Validate with A/B and keep only if >=5% positive.
