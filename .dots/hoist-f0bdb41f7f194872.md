---
title: Add interference test
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T21:20:59.474354+02:00"
---

File: tests/interference.zig (new). Create 3 vregs: v0=[0,5], v1=[3,7], v2=[8,10]. Build interference graph. Verify: v0 interferes with v1 (overlap), v0/v1 don't interfere with v2 (no overlap). ~15 min.
