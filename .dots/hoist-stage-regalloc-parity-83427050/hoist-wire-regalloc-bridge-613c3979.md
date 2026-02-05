---
title: Wire regalloc bridge atomics
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-05T21:41:39.707444+01:00\\\"\""
closed-at: "2026-02-05T21:44:17.775230+01:00"
close-reason: Support atomic/acquire-release variants in regalloc bridge
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/regalloc_bridge.zig:48 and /Users/joel/Work/hoist/src/backends/aarch64/inst.zig:3027; cause: atomic/acquire-release variants are unsupported in bridge and fail parity workloads; fix: add extract/apply support for ldar/stlr/ldxr/stxr/ldaxr/stlxr/ldadd-family/cas-family/swp; deps: hoist-wire-regalloc-bridge-ff692350; verification: new atomic bridge tests + zig build test -j1 --global-cache-dir .zig-global-cache
