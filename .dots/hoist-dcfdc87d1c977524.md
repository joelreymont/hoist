---
title: Emit eh_frame section
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:08:06.839564+02:00"
---

File: src/codegen/compile.zig. After code emission, generate .eh_frame section with unwind info. Include in JIT memory layout. Register with runtime for exception unwinding. Platform-specific (macOS uses libunwind). ~25 min.
