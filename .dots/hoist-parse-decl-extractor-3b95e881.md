---
title: Parse decl/extractor/extern
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T20:15:55.206349+01:00"
---

Full context: src/dsl/isle/parser.zig:119/229/264/276 decl/extractor/extern syntax mismatches .isle (arg lists, pure prefix, extern kind). Cause: parser expects flat symbols. Fix: parse arg lists, pure-before, extractor form, extern constructor/extractor. Why: unblock ISLE semantics.
