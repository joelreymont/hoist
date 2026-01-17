---
title: Verify soft-float libcalls
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:06:44.844632+02:00"
---

Files: src/ir/libcall.zig
What: Verify soft-float calling convention matches Cranelift
Check: __addsf3, __divsf3, etc. signatures and behavior
Method: Compare libcall list and signatures with Cranelift
Verification: Identical soft-float behavior
