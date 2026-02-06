---
title: Lower dyn_scale_target_const gv
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T10:52:33.160256+01:00\""
closed-at: "2026-02-06T10:58:36.800807+01:00"
close-reason: Lowered dyn_scale_target_const and added unit test
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/isle_impl.zig:1978; cause: dyn_scale_target_const global value returns error.Unimplemented; fix: lower to pointer-sized mov_imm scale matching Cranelift legalizer semantics (dynamic_vector_bytes/base_bytes); deps: PLAN.md section 8/appendix unresolved TODO; verification: add isle_impl unit test + zig build test -j1 --global-cache-dir .zig-global-cache
