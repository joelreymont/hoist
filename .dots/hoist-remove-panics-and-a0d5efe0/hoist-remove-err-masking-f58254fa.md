---
title: Remove Error Masking in Tests
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.569590+01:00"
---

Context: src/foundation/entity.zig:413; cause: catch unreachable/orelse unreachable; fix: propagate errors in tests and code; deps: hoist-remove-panics-and-a0d5efe0; verification: zig build test
