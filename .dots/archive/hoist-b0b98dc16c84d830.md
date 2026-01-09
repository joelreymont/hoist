---
title: Test HFA/HVA passing
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T07:48:06.563110+02:00\""
closed-at: "2026-01-09T08:00:22.551911+02:00"
---

Write comprehensive tests: float[4] in s0-s3, double[2] in d0-d1, vector<f32,4>[2] in v0-v1. Test edge cases: 5 floats (too many), mixed types (not homogeneous). Files: tests/aarch64_hfa_hva.zig (new), ~200 lines. ~90 min.
