---
title: Add HFA return marshaling test
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:14:51.475173+01:00\""
closed-at: "2026-02-06T20:17:14.063007+01:00"
close-reason: Replace TODO with explicit aarch64 classifyReturn HFA f64x2 assertions for V0-V1 mapping
---

Context: /Users/joel/Work/hoist/tests/aarch64_return_marshaling.zig:480 TODO; cause: missing explicit HFA return marshaling coverage in this test suite; fix: add AArch64 compile test for struct {f64,f64} parameter returned directly; deps: existing return marshaling tests; verification: zig build test -j1 --global-cache-dir .zig-global-cache
