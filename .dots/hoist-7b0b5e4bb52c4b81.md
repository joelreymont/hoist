---
title: Preserve exception value
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:07:34.579208+02:00"
---

File: src/backends/aarch64/abi.zig. Define exception value ABI: use X0 for exception pointer (AAPCS64 convention). Ensure landing pad receives exception value in X0. Add test for exception value propagation. ~20 min.
