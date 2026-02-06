---
title: Consolidate overflow-carry ISLE tests
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T23:49:18.299125+01:00\""
closed-at: "2026-02-06T23:49:42.166546+01:00"
close-reason: Dropped duplicate helper-side overflow_cin path and added constructor-level coverage in isle_impl tests
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/isle_impl.zig:1519 and /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig:3720; cause: remove duplicate overflow-carry helpers/tests from helpers and validate primary ISLE constructors in isle_impl directly; fix: add constructor-level tests for uadd/sadd overflow_cin in isle_impl and keep helper file DRY; deps: hoist-implement-overflow-carry-b62829b7; verification: zig build test -j1 --global-cache-dir .zig-global-cache
