---
title: Fix HFA stack passing
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:51:22.400514+02:00\""
closed-at: "2026-01-24T00:20:04.503602+02:00"
---

In src/backends/aarch64/isle_helpers.zig:3059,3567,4009, implement TODO: Stack HFA handling. Place HFA fields on stack per AAPCS64. Deps: none. Verify: zig build test
