---
title: Wire constant pool to lowering (~60 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:22:56.089654+02:00"
closed-at: "2026-01-05T13:15:36.451192+02:00"
---

File: src/backend/lower_ctx.zig. Add constant pool field to LowerCtx. Use in ISLE constructors for large immediates. Depends on: ConstantPool. Est: 15 min.
