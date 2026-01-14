---
title: Emit x64 branch
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.366046+02:00"
---

Files: src/backends/x64/emit.zig:11-30
Root cause: branch/call encodings are stub rel32 only.
Fix: implement jcc/jmp/call encodings, label fixups, and indirect call/jmp.
Why: correct control flow.
Deps: Add x64 branch.
Verify: branch encoding tests.
