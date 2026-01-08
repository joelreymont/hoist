---
title: Hook spill insertion into compile pipeline
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T11:46:25.494999+02:00"
---

File: src/machinst/compile.zig. Add call to regalloc pipeline after lowering. Pass result to ISA insertSpillReloads(). Add e2e test with spilled value. Dependencies: regalloc pipeline entry. Effort: <30min
