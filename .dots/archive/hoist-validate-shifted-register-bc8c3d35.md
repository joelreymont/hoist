---
title: Validate shifted register operands
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T22:20:55.972801+01:00\""
closed-at: "2026-02-06T22:23:52.053299+01:00"
close-reason: Add shift-op/amount validation for shifted-register encoders
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/emit.zig:652,1273; cause: add/sub/logical shifted register encoders accept invalid 32-bit shift amounts and add/sub accept illegal ROR shift op; fix: add explicit validation helpers and regression tests for invalid shift amount/opcode; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
