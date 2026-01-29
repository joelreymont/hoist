---
title: Compile cleanup
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T20:16:15.812402+01:00"
---

Full context: src/dsl/isle/compile.zig:135 cleanup skips extractor/let/pattern nodes. Cause: incomplete AST teardown. Fix: deep free extractor/extern/let/bind/wildcard/etc. Why: avoid leaks.
