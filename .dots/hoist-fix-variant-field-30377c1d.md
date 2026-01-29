---
title: Fix variant field
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T18:27:04.064652+01:00"
---

Context: src/dsl/isle/codegen/constructors.zig:295-298; cause: variant field name hardcoded to "fields"; fix: use typeenv to emit actual field name; deps: none; verification: zig build test
