---
title: Remove Error Masking in Tests
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.569590+01:00\""
closed-at: "2026-02-01T18:27:34.244281+01:00"
close-reason: "completed: removed error masking; tests now propagate errors (e.g., src/foundation/entity.zig:408-414 uses try bufPrint) and rg shows no catch return/unreachable in tests"
---

Context: src/foundation/entity.zig:413; cause: catch unreachable/orelse unreachable; fix: propagate errors in tests and code; deps: hoist-remove-panics-and-a0d5efe0; verification: zig build test
