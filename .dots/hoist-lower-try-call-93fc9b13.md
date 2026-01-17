---
title: Lower try_call with exception
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:33.309362+02:00"
---

In aarch64_lower_generated.zig:2665, implement try_call exception check. CBZ X0 to normal path, else landing pad. Deps: Wire exception edges to CFG. Verify: zig build test
