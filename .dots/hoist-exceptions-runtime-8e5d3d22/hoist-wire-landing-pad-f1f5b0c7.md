---
title: Wire landing pad edge
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-30T11:27:04.102056+01:00\\\"\""
closed-at: "2026-01-31T17:42:14.212308+01:00"
---

Context: src/backends/aarch64/isle_helpers.zig:4762; cause: exception edge TODO; fix: plumb landing pad block into try_call lowering; deps: CFG exception edges; verification: add EH tests + zig build test
