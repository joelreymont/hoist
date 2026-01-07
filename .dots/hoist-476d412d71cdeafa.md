---
title: "Implement Value Use Tracking - src/machinst/vcode_builder.zig - Track vreg use counts, implement value sinking logic (emit when last use encountered), add multi-result handling. ~150 lines. Cranelift ref: machinst/lower.rs:use_vreg_at. Test: Unit test verifying sinking. Commit: Implement value use tracking and sinking"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-02T22:07:10.768000+02:00"
closed-at: "2026-01-02T23:22:17.310507+02:00"
---

Implementing value use tracking
