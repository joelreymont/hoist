---
title: Lower try_call with exception
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:53:33.309362+02:00\""
closed-at: "2026-01-26T09:03:18.737807+01:00"
---

In aarch64_lower_generated.zig:2665, implement try_call exception check. CBZ X0 to normal path, else landing pad. Deps: Wire exception edges to CFG. Verify: zig build test
