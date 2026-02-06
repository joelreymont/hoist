---
title: Fix AArch64 imm9 offset truncation
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T21:54:52.940610+01:00\\\"\""
closed-at: "2026-02-06T21:56:53.163422+01:00"
close-reason: Added signed imm9 range checks and out-of-range tests
---

src/backends/aarch64/emit.zig: emitLdr/emitStr/emitLdrPre/Post/emitStrPre/Post truncated i16 offsets to imm9 without range checks, silently misencoding out-of-range offsets. Add signed imm9 bounds helper and regression tests for OffsetOutOfRange.
