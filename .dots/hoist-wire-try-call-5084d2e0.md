---
title: Wire try_call_indirect
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T18:27:04.081094+01:00"
---

Context: src/backends/aarch64/isle_helpers.zig:4686-4693; cause: indirect try_call lacks exception edge wiring; fix: plumb TryCallData exception successor into lowering; deps: none; verification: zig build test
