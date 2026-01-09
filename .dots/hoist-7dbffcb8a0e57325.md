---
title: Add CallConv field to Signature
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T07:45:41.868349+02:00"
---

Extend src/ir/signature.zig:Signature struct to include calling_convention: CallingConvention field. Update init() and tests. Default to .C convention. Files: src/ir/signature.zig:20-40. ~20 min.
