---
title: EntityRef test bufPrint
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T14:33:09.010897+01:00\""
closed-at: "2026-02-01T14:33:39.476777+01:00"
close-reason: completed
---

src/foundation/entity.zig:413 cause: bufPrint error masked with catch unreachable; fix: use try in test; why: no error masking in tests.
