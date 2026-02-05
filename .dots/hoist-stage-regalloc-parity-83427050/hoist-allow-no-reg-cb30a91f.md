---
title: Allow no-reg control variants
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-05T21:44:42.595068+01:00\\\"\""
closed-at: "2026-02-05T21:48:13.485817+01:00"
close-reason: Added no-reg passthrough and coverage
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/regalloc_bridge.zig:48; cause: bridge errors on control/no-register instruction variants that should pass through; fix: add explicit passthrough cases for branch/ret/barrier/trap/data/nop and test; deps: hoist-wire-regalloc-bridge-613c3979; verification: new passthrough tests + zig build test -j1 --global-cache-dir .zig-global-cache
