---
title: Add vector return classification
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T07:48:06.558155+02:00\""
closed-at: "2026-01-09T08:00:22.177650+02:00"
---

Handle vector returns in v0, HFA returns in s0-s3/d0-d3, HVA returns in v0-v3. Update classifyReturn() to cover all cases. Files: src/backends/aarch64/abi.zig:90-130 (extend). ~60 min.
