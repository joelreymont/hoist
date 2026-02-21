---
title: lower single-block maps fast
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T21:05:18.562298+01:00\\\"\""
closed-at: "2026-02-21T21:17:12.190907+01:00"
close-reason: "discarded: no >=5% retained gains (report /tmp/hoist-2x-loop-report3-r9.md)"
---

Context: src/codegen/compile.zig lowerAArch64 allocates block_index_map and ir_to_vcode_blocks hash maps even for single-block functions; fix: single-block path with stack locals/no hash maps.
