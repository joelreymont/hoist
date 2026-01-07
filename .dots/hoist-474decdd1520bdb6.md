---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:44:32.229674+02:00"
closed-at: "2026-01-01T09:05:26.859813+02:00"
close-reason: Replaced with correctly titled task
---

Port lowering infrastructure from cranelift/codegen/src/machinst/lower.rs (~2000 LOC). Create src/machinst/lower.zig with LowerCtx, ISLE integration hooks, instruction emission helpers. Depends on: VCode (hoist-474deb7f9da39c2f), IR function (hoist-474de8b519abfca8), ISLE compiler (hoist-474dea951b7c65e0). Files: src/machinst/lower.zig. Framework for IR→MachInst lowering via ISLE.
