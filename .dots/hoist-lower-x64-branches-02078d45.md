---
title: Lower x64 branches
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T18:27:04.077844+01:00"
---

Context: src/backends/x64/lower.zig:33-60; cause: branch lowering is stubbed; fix: emit compare + jcc/jmp for IR branches; deps: Lower x64 ALU; verification: zig build test
