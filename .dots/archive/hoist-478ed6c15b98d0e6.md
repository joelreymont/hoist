---
title: "P2.9.0: Implement amode infrastructure"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T14:11:14.188194+02:00"
closed-at: "2026-01-04T14:26:54.502547+02:00"
---

File: src/backends/aarch64/inst.isle + isle_helpers.zig - BLOCKED: Load/store patterns require 'amode' constructor that optimizes address+offset into ARM64 addressing modes (Unscaled/RegScaled/RegReg/etc). Need: (1) amode(Type Value i32) constructor with optimization rules, (2) pair_amode for I128, (3) simm9_from_i64 extractor, (4) i32_checked_add helper. Cranelift inst.isle has ~20 amode optimization rules. This is significant infrastructure work.
