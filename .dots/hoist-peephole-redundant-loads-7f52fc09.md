---
title: Peephole redundant loads
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T18:27:04.099380+01:00"
---

Context: src/codegen/peephole.zig:131-139; cause: redundant load elimination not implemented; fix: add alias-aware load redundancy pass; deps: none; verification: zig build test
