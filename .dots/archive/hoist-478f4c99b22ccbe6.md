---
title: Fix arg_ty isVector unwrapping
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T14:44:11.300407+02:00"
closed-at: "2026-01-04T14:44:32.924642+02:00"
---

File: src/ir/verifier.zig:396 - Error: no field or member function named 'isVector' in '?ir.types.Type'. arg_ty is ?Type but code calls .isVector() without unwrapping. Need to unwrap optional before calling method.
