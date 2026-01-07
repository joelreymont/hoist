---
title: Implement interval sorting
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:00:08.874705+02:00"
closed-at: "2026-01-06T22:30:00.885472+02:00"
---

File: src/regalloc/linear_scan.zig - Sort all live ranges by start_inst (ascending). Use std.sort with custom compareFn. This is the key step that enables linear scan. Dependencies: hoist-47b466c3ad32edaf.
