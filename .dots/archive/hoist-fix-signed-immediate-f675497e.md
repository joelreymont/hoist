---
title: Fix signed immediate add/sub lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:31:23.724863+01:00\""
closed-at: "2026-02-06T20:34:08.482092+01:00"
close-reason: Correct signed immediate lowering without modulo truncation and add negative/large immediate regression tests
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:3865,3904; cause: iadd_imm/irsub_imm use modulo 4096 truncation, producing wrong code for negative or large immediates; fix: use add_imm/sub_imm only for encodable signed cases and fallback to mov_imm+add_rr/sub_rr; deps: none; verification: add negative/large immediate lowering tests and run zig build test -j1 --global-cache-dir .zig-global-cache
