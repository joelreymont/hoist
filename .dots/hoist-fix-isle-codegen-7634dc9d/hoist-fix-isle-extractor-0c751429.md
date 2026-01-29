---
title: Fix ISLE Extractor Bindings
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.513923+01:00"
---

Context: src/dsl/isle/codegen/extractors.zig:197; cause: bindings discarded; fix: store bindings for later use in generated code; deps: hoist-fix-isle-extractor-f35b82c1; verification: isle extractor tests
