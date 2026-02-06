---
title: Lower x64 ALU
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.722220+01:00\""
closed-at: "2026-02-06T11:17:11.693588+01:00"
close-reason: Implemented x64 ALU lowering in backend lowerInst and added coverage tests.
blocks:
  - hoist-wire-x64-lowering-ca9077ad
---

Context: src/backends/x64/lower.zig:20-52; cause: lowerInst returns false for all ops; fix: implement lowering for core ALU ops (iadd/isub/imul/icmp/iconst); deps: none; verification: zig build test
