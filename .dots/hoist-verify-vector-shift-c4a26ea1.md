---
title: Verify vector shift masking
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:06:16.659465+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:6320-6323
What: Verify shift amount handling matches Cranelift
Currently: Wraps rather than saturates
Question: Does Cranelift mask or saturate shift amounts?
Fix: Match Cranelift's behavior exactly
Verification: Compare output with Cranelift for edge cases
