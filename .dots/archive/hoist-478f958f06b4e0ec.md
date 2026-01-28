---
title: Fix root.passes missing import
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T15:04:35.337918+02:00"
closed-at: "2026-01-04T15:05:10.599989+02:00"
---

File: src/context.zig:75 - Error: root source file struct 'root' has no member named 'passes'. Need to check if passes module exists in root.zig or use proper import path.
