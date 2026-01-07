---
title: Implement CCMP encoding in emit.zig
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T22:27:46.649663+02:00"
---

File: src/backends/aarch64/emit.zig - Add emitCcmp and emitCcmn functions. Encoding: sf=size bit, op=0 for CCMP/1 for CCMN, S=1, cond in bits 12-15, Rn, o2=0, o3, Rm/imm5, nzcv in bits 0-3. Verify with ARM ARM section C6.2.53. Depends on hoist-d59f573904bea683.
