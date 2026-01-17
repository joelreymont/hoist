---
title: Refactor iconst
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-17T12:46:36.962081+02:00\\\"\""
closed-at: "2026-01-17T13:17:22.866018+02:00"
---

Files: src/codegen/compile.zig:1311-1631. Cause: repeated MOVN/MOVK sequences per halfword. Fix: extract helper to emit immediate construction and reuse; keep logic identical. Why: DRY and safer edits. Verify: zig build test + encoding tests.
