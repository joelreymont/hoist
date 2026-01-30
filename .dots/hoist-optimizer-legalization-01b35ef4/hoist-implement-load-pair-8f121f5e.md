---
title: Implement load-pair combine
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-30T11:26:10.944016+01:00\\\"\""
closed-at: "2026-01-30T13:30:26.789332+01:00"
close-reason: completed
---

Context: src/codegen/peephole.zig:99; cause: LDP combine TODO; fix: detect adjacent loads and merge into pair when safe; deps: none; verification: add peephole tests + zig build test
