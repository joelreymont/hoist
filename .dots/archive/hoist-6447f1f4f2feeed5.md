---
title: Implement Spectre mitigation pass
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T08:18:07.772383+02:00\""
closed-at: "2026-01-09T08:40:47.361127+02:00"
---

Create src/codegen/opts/spectre.zig. Insert spectre_fence after: bounds checks, branch misprediction points, sensitive data loads. Use control flow analysis from cfg.zig. Add pass registration in optimize.zig. ~90-120 min.
