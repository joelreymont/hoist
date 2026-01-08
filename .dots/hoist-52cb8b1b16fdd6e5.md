---
title: Populate Function.signatures during IR construction
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T12:58:31.726225+02:00"
---

File: src/ir - When creating call/call_indirect instructions, register their signature in func.signatures map. Extract sig from FuncRef during instruction creation. Ensures signatures are available for validation during lowering. Depends on: Function.signatures field. Blocks: signature validation tests.
