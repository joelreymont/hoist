---
title: Implement store-pair combine
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-30T11:26:15.036719+01:00\\\"\""
closed-at: "2026-01-30T13:30:36.422934+01:00"
close-reason: completed
---

Context: src/codegen/peephole.zig:117; cause: STP combine TODO; fix: detect adjacent stores and merge into pair when safe; deps: none; verification: add peephole tests + zig build test
