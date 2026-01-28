---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:43:53.958279+02:00"
closed-at: "2026-01-01T09:05:17.962119+02:00"
close-reason: Replaced with correctly titled task
---

Port ISLE compiler driver from cranelift/isle/isle/src/{lib.rs,compile.rs} (~500 LOC). Create src/dsl/isle/compiler.zig with compile() entry point. Depends on: all ISLE components (hoist-474dea3be0fc3948). Files: src/dsl/isle/compiler.zig, isle_test.zig. Complete ISLE → Zig compiler. Can now compile .isle files to .zig!
