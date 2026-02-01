---
title: SSA tests missing block
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T14:34:32.408061+01:00\""
closed-at: "2026-02-01T14:35:00.489510+01:00"
close-reason: completed
---

src/ir/ssa_tests.zig:157/404/483 cause: orelse unreachable masks missing blocks; fix: return error.MissingBlock when getMut fails; why: no error masking in tests.
