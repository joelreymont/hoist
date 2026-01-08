---
title: Emit eh_frame section
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T20:08:06.839564+02:00\""
closed-at: "2026-01-08T21:21:20.150012+02:00"
---

File: src/codegen/compile.zig. After code emission, generate .eh_frame section with unwind info. Include in JIT memory layout. Register with runtime for exception unwinding. Platform-specific (macOS uses libunwind). ~25 min.
