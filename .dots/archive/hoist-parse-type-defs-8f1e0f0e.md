---
title: Parse type defs
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T20:15:51.275415+01:00\""
closed-at: "2026-01-29T20:30:33.605916+01:00"
close-reason: completed
---

Full context: src/dsl/isle/parser.zig:135 type defs skip extern/primitive/enum forms in lower.isle. Cause: parser only handles primitive symbol/enum list. Fix: parse extern flag and (primitive)/(enum ...) forms. Why: parse backend ISLE files.
