---
title: Add memcpy helper for large structs
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T08:19:33.560041+02:00\""
closed-at: "2026-01-09T12:41:50.126031+02:00"
---

Create abi.generateStructCopy() in src/backends/aarch64/abi.zig. Emit LDP/STP loop for struct copy (8/16-byte chunks). Used for >16 byte structs passed by reference. ~60 min.
