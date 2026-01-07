---
title: Extend jit_harness.zig for validation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:11:33.494693+02:00"
closed-at: "2026-01-07T14:30:33.933747+02:00"
---

File: src/backends/aarch64/jit_harness.zig (exists, extend)
Currently: Basic JIT infrastructure
Need: Add test helpers - compileAndExecute(ir_text) helper, comparison with expected results, memory leak checking, register state validation
Dependencies: First integration dot
Estimated: 2 days
Test: Run E2E tests through harness
