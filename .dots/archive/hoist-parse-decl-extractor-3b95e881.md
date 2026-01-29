---
title: Parse decl/extractor/extern
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T20:15:55.206349+01:00\""
closed-at: "2026-01-29T20:30:37.700461+01:00"
close-reason: completed
---

Full context: src/dsl/isle/parser.zig:119/229/264/276 decl/extractor/extern syntax mismatches .isle (arg lists, pure prefix, extern kind). Cause: parser expects flat symbols. Fix: parse arg lists, pure-before, extractor form, extern constructor/extractor. Why: unblock ISLE semantics.
