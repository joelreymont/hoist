---
title: Verify stack arg ABI layouts
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:13:28.557005+01:00\""
closed-at: "2026-02-06T20:14:16.561871+01:00"
close-reason: Replace stack-arg TODOs with concrete computeArgLocs assertions for int/float/mixed/overflow/small-type cases
---

Context: /Users/joel/Work/hoist/tests/aarch64_stack_args.zig TODO markers for stack arg placement; cause: tests lacked concrete ABI location assertions; fix: assert computeArgLocs register/stack placement for int/float/mixed/small-type/overflow cases; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache
