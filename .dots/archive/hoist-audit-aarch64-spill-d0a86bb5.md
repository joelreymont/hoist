---
title: Audit AArch64 spill/reload path
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T19:12:20.283674+01:00\""
closed-at: "2026-02-06T19:17:17.164482+01:00"
close-reason: Spill/reload insertion and frame-size wiring implemented with tests.
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/isa.zig:401 and /Users/joel/Work/hoist/src/backends/aarch64/regalloc_bridge.zig:701; cause: regalloc2 stack allocations currently unsupported in applyAllocations, stack_frame_size forced 0; fix: wire spill/reload insertion for stack allocations and propagate frame size; deps: hoist-integrate-regalloc2-8f36d248; verification: add aarch64 regalloc2 spill test + zig build test
