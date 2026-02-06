---
title: Audit AArch64 spill/reload path
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T19:49:25.322403+01:00\""
closed-at: "2026-02-06T19:54:41.008302+01:00"
close-reason: Added class-aware spill/reload handling and vector spill tests
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/isa.zig:343; cause: verify spill/reload path matches regalloc2 expectations for aarch64; fix: add/adjust spill slot usage and reload insertion tests if mismatched; deps: hoist-integrate-regalloc2-8f36d248; verification: new aarch64 spill test + zig build test
