---
title: Verify istore8 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T19:28:23.820396+01:00\""
closed-at: "2026-02-06T19:39:18.952992+01:00"
close-reason: Verified STRB lowering; existing tests already cover path
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:4786 and /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig:3375. Cause: ensure istore8 lowers to STRB with correct reg class/addressing. Fix: adjust lowering or constructor path and add regression test. Dependencies: PLAN.md section 8. Verification: zig build test -j1 --global-cache-dir .zig-global-cache.
