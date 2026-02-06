---
title: Lower x64 branches
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.729146+01:00\""
closed-at: "2026-02-06T11:17:11.711760+01:00"
close-reason: Implemented x64 branch terminator lowering and added branch regression test.
blocks:
  - hoist-lower-x64-alu-3bfabb3f
---

Context: src/backends/x64/lower.zig:33-60; cause: branch lowering is stubbed; fix: emit compare + jcc/jmp for IR branches; deps: Lower x64 ALU; verification: zig build test
