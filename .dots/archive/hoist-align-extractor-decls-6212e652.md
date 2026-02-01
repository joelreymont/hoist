---
title: Align extractor decls and helpers
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T21:40:36.607657+01:00\\\"\""
closed-at: "2026-02-01T21:14:28.043192+01:00"
close-reason: completed
---

Context: src/backends/aarch64/lower.isle:33,3610; src/backends/aarch64/isle_helpers.zig:4836; cause: extractor decls/helpers mismatched with matching semantics; fix: adjust extractor decls (multi_lane/u128_from_immediate) and helper signatures, add helper tests; deps: hoist-support-extern-extractor-3bffb45e; verification: NO_COLOR=1 zig build test
