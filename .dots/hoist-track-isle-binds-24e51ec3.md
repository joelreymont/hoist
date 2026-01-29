---
title: Track ISLE binds
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T18:27:04.060841+01:00"
---

Context: src/dsl/isle/codegen/extractors.zig:197; cause: bind patterns do not store bindings for later use; fix: record binding IDs and plumb through extractor output; deps: Handle ISLE extractors; verification: zig build test
