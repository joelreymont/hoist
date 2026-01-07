---
title: "Dot 0.2: Implement multi_lane extractor"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T06:47:32.624524+02:00"
closed-at: "2026-01-04T06:52:26.278136+02:00"
---

File: src/backends/aarch64/isle_helpers.zig:1565. Add: pub fn multi_lane(ty: types.Type) ?struct{u32,u32}. Check ty.isVector(), return {lane_bits,lane_count} or null. Test: I8X16->{8,16}, I32X4->{32,4}, I64->null. 20min. Depends: 0.1
