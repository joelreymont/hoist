---
title: Add ISLE patterns for CCMP compare chains
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T22:27:54.419325+02:00\""
closed-at: "2026-01-08T15:01:21.561162+02:00"
---

File: src/backends/aarch64/isle_impl.zig - Add ISLE constructors for recognizing compare chains like select(icmp_and(cmp1, cmp2), ...) and lowering to CCMP sequences. Pattern: first compare sets flags normally, second uses CCMP conditioned on first. Must handle both AND and OR chains. Reference Cranelift lower.isle lines 314, 1084 for patterns. Depends on hoist-7446fbe436a0bcaf.
