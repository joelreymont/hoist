---
title: Implement 40-live-value spill e2e
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T19:59:20.756329+01:00\""
closed-at: "2026-02-06T20:02:19.764657+01:00"
close-reason: Implemented 40-live-value spill e2e and allocator fallback spill
---

Context: /Users/joel/Work/hoist/tests/e2e_jit.zig:572; cause: spill coverage test was skipped; fix: build 40-live-value function and assert aarch64 spill_bytes > 0 via codegen context; deps: hoist-audit-aarch64-spill-31bf5256; verification: zig build test -j1 --global-cache-dir .zig-global-cache
