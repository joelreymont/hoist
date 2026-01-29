---
title: Fix variant field
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T18:27:04.064652+01:00\""
closed-at: "2026-01-29T19:23:05.563193+01:00"
close-reason: completed
---

Context: src/dsl/isle/codegen/constructors.zig:295-298; cause: variant field name hardcoded to "fields"; fix: use typeenv to emit actual field name; deps: none; verification: zig build test
