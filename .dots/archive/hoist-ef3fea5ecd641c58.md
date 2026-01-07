---
title: Implement LD1R vector load-replicate
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T22:28:00.834762+02:00\""
closed-at: "2026-01-07T22:51:24.816946+02:00"
---

File: src/backends/aarch64/inst.zig - Add LD1R instruction for loading a single element from memory and replicating across all vector lanes. Variants: LD1R.{8B,16B,4H,8H,2S,4S,2D}. More efficient than separate load+DUP. Critical optimization for vector constant initialization. Need: instruction struct, encoding, ISLE pattern for splat(load(addr)).
