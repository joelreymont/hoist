---
title: Implement CCMP/CCMN conditional compare
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T22:27:28.359343+02:00\""
closed-at: "2026-01-07T23:02:13.123938+02:00"
---

File: src/backends/aarch64/inst.zig - Add CCMP/CCMN instruction structs for conditional compare. These instructions compare two values only if a prior condition is true, allowing efficient chaining of comparisons without branches. Critical for i128 operations and multi-condition tests. Cranelift uses extensively in lower.isle. Need: instruction struct, encoding in emit.zig, ISLE patterns for compare chains.
