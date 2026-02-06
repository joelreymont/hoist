---
title: Harden try_call e2e tests
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T21:39:56.133727+01:00\\\"\""
closed-at: "2026-02-06T21:41:12.739331+01:00"
close-reason: Replaced placeholder func refs and fixed duplicate jump
---

tests/e2e_jit.zig:635,772,905 currently use placeholder FuncRef.new(0) and one test appends duplicate jumps in same block. Replace with registered external function metadata via func.addSignature/registerExternalFunc; keep exception edge + landingpad assertions; remove duplicate jump from basic test; verify with zig build test -j1 --global-cache-dir .zig-global-cache. Depends on PLAN.md try_call parity section. Est: 30m
