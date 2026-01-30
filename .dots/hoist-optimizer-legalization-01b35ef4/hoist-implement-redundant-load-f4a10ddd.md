---
title: Implement redundant-load elim
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-30T11:26:18.344558+01:00\\\"\""
closed-at: "2026-01-30T13:35:21.920209+01:00"
close-reason: completed
---

Context: src/codegen/peephole.zig:139; cause: redundant load elimination TODO; fix: remove reloads when value unchanged and register still live; deps: none; verification: add peephole tests + zig build test
