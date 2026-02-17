---
title: Remap after spill rewrite
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-17T10:38:33.798294+01:00\""
closed-at: "2026-02-17T10:38:33.829287+01:00"
close-reason: completed in jj commit 52a99349 with passing test, integration, jit, fuzz
---

File: /Users/joel/Work/hoist/src/codegen/compile.zig:705,797. Cause: spill rewrite replaces insn stream and invalidates phi group indices. Fix: build insn_map old->new and remap phi_copy_groups first_insn after rewrite. Why: keep phi groups valid for post-regalloc pass.
