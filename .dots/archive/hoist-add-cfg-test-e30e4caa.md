---
title: Add CFG test for try_call_indirect edges
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:49:32.833073+01:00\""
closed-at: "2026-02-06T20:52:18.016887+01:00"
close-reason: Completed
---

Context: /Users/joel/Work/hoist/src/ir/cfg.zig:486 has try_call exception-successor coverage but no try_call_indirect counterpart. Cause: missing regression test for exception edge plumbing on indirect exceptional calls. Fix: add cfg unit test that builds try_call_indirect with normal and exception successors and asserts succ/exceptionSucc iterators. Deps: none. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
