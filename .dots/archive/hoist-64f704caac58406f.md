---
title: Add signatures PrimaryMap to Function struct
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T12:44:53.077193+02:00\""
closed-at: "2026-01-08T12:49:27.880864+02:00"
---

File: src/ir/function.zig - Add 'signatures: PrimaryMap(SigRef, Signature)' field to Function struct. Initialize in init(), deinit in deinit(). This will store all signatures referenced by the function (for calls, indirect calls, etc.). Depends on: none. Enables: signature validation in lowering.
