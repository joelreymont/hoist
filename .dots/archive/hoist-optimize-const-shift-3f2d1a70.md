---
title: Optimize const shift/bitop lowering
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T09:56:54.003131+01:00\\\"\""
closed-at: "2026-02-06T09:59:10.077779+01:00"
close-reason: Added iconst detection and immediate-form emission for shift/bitwise binops with RR fallback; tests pass.
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:2691,2859; cause: TODOs leave register-register forms when RHS is iconst; fix: detect iconst operands and emit immediate forms (lsl/lsr/asr imm, and/orr/eor imm) with fallback to RR when encoding invalid; deps: hoist-optimizer-legalization-eddf172d; verification: zig build test -j1 --global-cache-dir .zig-global-cache
