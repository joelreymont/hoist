---
title: Add TLS Local Exec instruction variants
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T12:45:12.057578+02:00"
---

File: src/backends/aarch64/inst.zig - Add MRS (read TP register) and ADD (add TLS offset) instruction variants for Local Exec TLS model. Lines ~200-300. Depends on: none. Enables: fastest TLS access for executables.
