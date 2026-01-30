---
title: Implement dead-move peephole
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:26:07.364567+01:00"
---

Context: src/codegen/peephole.zig:127; cause: dead move elimination TODO; fix: detect mov_rr where dst==src or overwritten before use; deps: none; verification: add peephole tests + zig build test
