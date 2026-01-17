---
title: Extend ValueRegs to 4
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:51:32.729511+02:00"
---

In src/backends/aarch64/isle_helpers.zig:3872, extend ValueRegs struct to support 4 registers instead of 2. Update all callsites. Deps: none. Verify: zig build test
