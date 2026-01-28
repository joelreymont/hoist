---
title: Fix emit.zig root imports for test compatibility
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:42:59.039067+02:00"
closed-at: "2026-01-05T16:50:08.707151+02:00"
---

File: src/backends/aarch64/emit.zig:4-14 - emit.zig uses @import("root") which breaks in test contexts. Need to refactor to use relative imports or conditional compilation. This blocks end-to-end emission testing. Once fixed, can implement emitAArch64VCode in compile.zig to walk VCode and emit machine code.
