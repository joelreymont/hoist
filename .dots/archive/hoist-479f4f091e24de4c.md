---
title: Port LibCall enum for runtime calls
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T09:50:11.633710+02:00"
closed-at: "2026-01-05T10:01:43.450164+02:00"
---

File: Create src/ir/libcall.zig from cranelift/codegen/src/ir/libcall.rs:1-129. LibCall enum defines runtime library functions called by lowering (memcpy, f32_to_i64, etc.). Each variant has associated signature. Root cause: runtime call indirection missing. Fix: Port LibCall enum with ~50 variants, add signature() method.
