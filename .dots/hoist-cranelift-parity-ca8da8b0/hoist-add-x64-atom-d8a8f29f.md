---
title: Add x64 atom
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.319312+02:00\""
closed-at: "2026-01-23T10:30:58.940569+02:00"
---

Files: src/backends/x64/inst.zig:12-93
Root cause: atomic/lock insts are missing.
Fix: add lock-prefixed RMW ops, cmpxchg/xadd, mfence/lfence/sfence.
Why: implement atomic IR ops on x64.
Deps: Add x64 mem.
Verify: extend inst format tests in src/backends/x64/inst.zig.
