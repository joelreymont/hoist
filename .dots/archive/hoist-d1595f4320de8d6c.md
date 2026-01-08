---
title: Add getSig method to LowerCtx
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T12:44:53.544929+02:00\""
closed-at: "2026-01-08T12:51:06.368185+02:00"
---

File: src/machinst/lower.zig - Add 'pub fn getSig(ctx: *LowerCtx, sig_ref: SigRef) ?Signature' method that looks up signature from Function.signatures. Returns null if not found. Depends on: signatures map in Function. Enables: call instruction lowering to validate signatures.
