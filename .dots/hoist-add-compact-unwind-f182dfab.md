---
title: Add compact unwind emission
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:33.314194+02:00"
---

Create src/backends/aarch64/unwind.zig. Generate Apple compact unwind info. Deps: Lower try_call with exception. Verify: zig build test
