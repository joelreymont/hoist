---
title: Fix emit test expectations
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T13:02:53.201617+02:00"
---

Files: src/backends/aarch64/emit.zig:6009, src/backends/aarch64/emit.zig:6158, src/backends/aarch64/emit.zig:6292, src/backends/aarch64/emit.zig:6421, src/backends/aarch64/emit.zig:6548, src/backends/aarch64/emit.zig:6670, src/backends/aarch64/emit.zig:7004, src/backends/aarch64/emit.zig:8484. Root cause: tests assert wrong bitfields/encodings for ADDS/SUBS/CMP/CMN immediates, TST immediate opcode mask, LSL immediate (UBFM imms), shift edge cases, and RET register expectations. Fix: update expected opcode masks/values and full encodings to match spec and emitter. Verify: zig build test.
