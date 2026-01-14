---
title: Add x64 sret
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.600755+02:00"
---

Files: src/backends/x64/abi.zig:19-57, src/backends/x64/lower.zig:12-55
Root cause: x64 struct return passing not implemented.
Fix: implement sret handling for SysV/Win64 and wire into call lowering.
Why: struct return correctness.
Deps: Add x64 mem, Wire x64 lower.
Verify: ABI tests for struct returns.
