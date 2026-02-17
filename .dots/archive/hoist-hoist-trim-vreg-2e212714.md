---
title: hoist-trim-vreg-origin-writes
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T08:34:20.246948+01:00\\\"\""
closed-at: "2026-02-18T08:44:09.508415+01:00"
close-reason: "completed: parent-vs-candidate repeat-9 A/B passed with >=5% wins on fib, large(100/500/1000/5000), int, vector, mixed, parallel batch"
---

src/codegen/compile.zig:2745,2771,2805,2833,2860,3228,3467 writes non-const VRegOrigin entries that insertSpillScratch never consumes; remove forBinop origin inserts, keep const origins only, then gate with repeat-9 no-regression perf compare
