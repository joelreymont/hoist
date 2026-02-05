---
title: Track regalloc2 vreg count
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T00:13:45.878945+01:00\""
closed-at: "2026-02-06T00:15:59.310279+01:00"
close-reason: Tracked vreg count from operands and added regalloc2 tests
---

Context: /Users/joel/Work/hoist/src/machinst/regalloc2/api.zig:addOperand and /Users/joel/Work/hoist/src/machinst/regalloc2/allocator.zig:run; cause: adapter does not advance num_vregs from observed operands so allocator skips all vregs in non-empty vcode; fix: track max vreg index in addOperand and correct stack-allocation typing; deps: hoist-stage-regalloc-parity-83427050; verification: add regalloc2 unit tests + zig build test -j1 --global-cache-dir .zig-global-cache
