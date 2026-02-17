---
title: Track phi group index
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-17T10:38:33.791079+01:00\""
closed-at: "2026-02-17T10:38:33.824662+01:00"
close-reason: completed in jj commit 52a99349 with passing test, integration, jit, fuzz
---

File: /Users/joel/Work/hoist/src/codegen/compile.zig:5637. Cause: first_insn omitted buffered current_block_insns in VCodeBuilder forward mode. Fix: compute first_insn as committed+buffered instruction count. Why: ensure phi group anchors to correct emitted MOV sequence.
