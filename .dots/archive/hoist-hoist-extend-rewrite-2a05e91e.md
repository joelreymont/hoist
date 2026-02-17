---
title: hoist-extend-rewrite-fastpath
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T09:17:39.257927+01:00\\\"\""
closed-at: "2026-02-18T09:20:37.004823+01:00"
close-reason: "discarded: repeat-9 A/B showed no >=5% gains and broad micro regressions"
---

src/codegen/compile.zig expand aarch64 simple rewrite fast path to include common spill/reload ops (mov_rr/add_imm/ldr/str plus existing mov_imm/add_rr/ret) so large functions hit fast path; immediate repeat-9 parent-vs-candidate A/B gate
