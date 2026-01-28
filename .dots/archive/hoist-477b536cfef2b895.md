---
title: Add ARM64 LL/SC atomic fallback ISLE rules
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T14:54:26.465532+02:00"
closed-at: "2026-01-03T16:07:31.690992+02:00"
---

File: src/backends/aarch64/lower.isle - Add LL/SC lowering: atomic_rmw→Loop(LDAXR + op + STLXR + branch-if-failed), atomic_cas→Loop(LDAXR + compare + STLXR + branch) - Handle all AtomicRmwOp variants - Accept: LL/SC generates loop-based atomics - Depends: 'Add atomic InstructionData variants'
