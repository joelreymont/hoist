---
title: Lower x64 branches
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.729146+01:00"
blocks:
  - hoist-lower-x64-alu-3bfabb3f
---

Context: src/backends/x64/lower.zig:33-60; cause: branch lowering is stubbed; fix: emit compare + jcc/jmp for IR branches; deps: Lower x64 ALU; verification: zig build test
