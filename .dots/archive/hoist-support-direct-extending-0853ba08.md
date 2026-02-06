---
title: Support direct extending load terms
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T01:00:02.085771+01:00\\\"\""
closed-at: "2026-02-06T01:05:14.722548+01:00"
close-reason: Added scalar extending-load ISLE terms and verified direct opcode lowering
---

Context: src/dsl/isle/ir_prelude.isle:740, src/dsl/isle/ir_externs.zig:936, src/backends/aarch64/lower.isle:1920; cause: direct uload*/sload* opcodes are not exposed as ISLE terms, which causes null-unwrapping panic paths during lowering; fix: add extractor terms + extern extractors for scalar extending loads and wire lowering rules; deps: hoist-exec-aarch64-parity-da78c5c3; verification: zig build test -j1 --global-cache-dir .zig-global-cache with direct load coverage tests
