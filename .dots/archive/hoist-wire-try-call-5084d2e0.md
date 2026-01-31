---
title: Wire try_call_indirect
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T18:27:04.081094+01:00\""
closed-at: "2026-01-31T14:55:01.280364+01:00"
close-reason: wired try_call_indirect lowering + test
---

Context: src/backends/aarch64/isle_helpers.zig:4686-4693; cause: indirect try_call lacks exception edge wiring; fix: plumb TryCallData exception successor into lowering; deps: none; verification: zig build test
