---
title: Add dot-finish workflow helper
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T19:55:57.493654+01:00\""
closed-at: "2026-02-06T19:56:40.791208+01:00"
close-reason: Added helper to enforce dot close/commit/push/new
---

Context: /Users/joel/Work/hoist/tools (new script); cause: AGENTS workflow mandates tools/dot-finish but file is missing; fix: add robust helper for test->dot off->jj describe->push->jj new; deps: none; verification: run helper with --help and run zig build test
