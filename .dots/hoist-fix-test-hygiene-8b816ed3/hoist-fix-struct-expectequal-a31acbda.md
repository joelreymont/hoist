---
title: Fix Struct ExpectEqual Tests
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.580039+01:00\""
closed-at: "2026-01-31T17:17:35.459492+01:00"
close-reason: use ohsnap for Pos in ast tests
---

Context: src/dsl/isle/ast.zig:182; cause: struct expectEqual forbidden; fix: replace with ohsnap snapshots; deps: hoist-fix-test-hygiene-8b816ed3; verification: zig test src/dsl/isle/ast.zig
