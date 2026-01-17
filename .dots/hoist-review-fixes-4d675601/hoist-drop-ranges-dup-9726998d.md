---
title: Drop ranges dup
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-17T12:46:36.947429+02:00\\\"\""
closed-at: "2026-01-17T13:17:34.889561+02:00"
---

Files: src/codegen/ranges.zig, src/foundation/ranges.zig. Cause: duplicated Ranges implementation. Fix: delete codegen/ranges.zig and update any imports to foundation/ranges.zig. Why: DRY, single source of truth. Verify: zig build test.
