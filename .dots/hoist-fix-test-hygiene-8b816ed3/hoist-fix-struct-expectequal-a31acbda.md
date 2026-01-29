---
title: Fix Struct ExpectEqual Tests
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.580039+01:00"
---

Context: src/dsl/isle/ast.zig:182; cause: struct expectEqual forbidden; fix: replace with ohsnap snapshots; deps: hoist-fix-test-hygiene-8b816ed3; verification: zig test src/dsl/isle/ast.zig
