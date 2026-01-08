---
title: Add FuncRef metadata system
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T22:31:40.483431+02:00\""
closed-at: "2026-01-08T22:33:38.113804+02:00"
---

File: src/ir/entities.zig or new src/ir/func_metadata.zig. FuncRef currently just wraps u32 index. Need: FuncMetadata struct with name (ExternalName), signature (SigRef), linkage. HashMap FuncRef -> FuncMetadata. API: registerExternalFunc(name, sig) -> FuncRef, getMetadata(FuncRef) -> FuncMetadata. Used by try_call lowering to extract callee info. ~20 min.
