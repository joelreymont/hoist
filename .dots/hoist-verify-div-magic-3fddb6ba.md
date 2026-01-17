---
title: Verify div magic constants
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:06:17.592649+02:00"
---

Files: src/codegen/div_const.zig
What: Verify magic number algorithm matches Cranelift/Hacker's Delight
Edge cases: Powers of 2, signed min, boundary values
Fix: Add comprehensive test cases comparing against Cranelift
Verification: Property-based testing of all u32/u64 divisors
