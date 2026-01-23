---
title: Verify HFA field ordering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:06:44.183559+02:00\""
closed-at: "2026-01-24T01:00:42.219516+02:00"
---

Files: src/backends/aarch64/abi.zig
What: Verify HFA field assembly order matches Cranelift
Question: Little-endian lane assembly order for vector aggregates?
Method: Create test HFA structs, compare register layout
Verification: Match Cranelift's HFA passing exactly
