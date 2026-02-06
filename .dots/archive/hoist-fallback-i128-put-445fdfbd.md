---
title: Fallback i128 put_in_regs mapping
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T21:22:12.612885+01:00\""
closed-at: "2026-02-06T21:24:11.477381+01:00"
close-reason: Use pinned-pair fallback and add regression coverage.
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig:4995 only handled iconcat I128 and returned Unimplemented for block params/other defs; cause: I128 register-pair consumers fail on non-iconcat values; fix: add pinned-pair fallback and regression test; deps: /Users/joel/Work/hoist/PLAN.md i128 parity hardening; verification: zig build test -j1 --global-cache-dir .zig-global-cache
