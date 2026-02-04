---
title: ISLE partial flow
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-05T01:25:39.089074+01:00\\\"\""
closed-at: "2026-02-05T18:45:49.610839+01:00"
close-reason: Fix optional constructor flow; tests pass
---

src/dsl/isle/codegen/constructors.zig + src/generated/isle/aarch64_lower_generated.zig:55061; cause: optional sub-constructors emit orelse-return-null even in non-partial constructors (return type !T), breaking compile; fix: optional-bind failure jumps to rule-fail path for non-partial constructors; only return null for partial; test: zig build test
