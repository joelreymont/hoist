---
title: Implement redundant-load elim
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:26:18.344558+01:00"
---

Context: src/codegen/peephole.zig:139; cause: redundant load elimination TODO; fix: remove reloads when value unchanged and register still live; deps: none; verification: add peephole tests + zig build test
