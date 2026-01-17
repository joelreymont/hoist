---
title: Complete VFPExpandImm encoding
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:52:39.405418+02:00"
---

In src/backends/aarch64/isle_helpers.zig:6751,6758, implement full VFPExpandImm encoding (±n/16 × 2^r). All 256 values. Deps: none. Verify: zig build test
