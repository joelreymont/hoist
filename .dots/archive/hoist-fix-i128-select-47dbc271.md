---
title: Fix i128 select cond lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T21:16:57.826815+01:00\""
closed-at: "2026-02-06T21:19:30.033866+01:00"
close-reason: Merge i128 cond lanes before compare; add regression.
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:3559 compares select condition as 32-bit scalar and ignores I128 high half; cause: I128 non-zero condition can miscompile; fix: OR low/high 64-bit lanes before compare and use 64-bit cmp, keep scalar path unchanged; deps: /Users/joel/Work/hoist/PLAN.md section 8 parity convergence; verification: add regression in /Users/joel/Work/hoist/tests/aarch64_ccmp.zig and run zig build test -j1 --global-cache-dir .zig-global-cache
