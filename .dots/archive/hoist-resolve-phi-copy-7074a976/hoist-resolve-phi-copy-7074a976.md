---
title: Resolve phi-copy review findings
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-17T10:38:33.786043+01:00\""
closed-at: "2026-02-17T10:38:33.847653+01:00"
close-reason: completed in jj commit 52a99349 with passing test, integration, jit, fuzz
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:851,6633 and /Users/joel/Work/hoist/src/machinst/vcode.zig:23. Root cause: post-regalloc phi parallel copy handling had index/remap/contiguity hazards. Fix: introduce phi_copy_groups in VCode, robust resolvePhiCopies pass, and spill-rewrite index remap. Why: prevent miscompilation in loop/merge/TCO paths.
