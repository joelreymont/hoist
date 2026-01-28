---
title: Add LD1+USHLL infrastructure for vector widening loads
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.785130+02:00"
closed-at: "2026-01-06T21:09:18.938062+02:00"
---

File: lower.isle. Add helper function for LD1 {v.8b}, [addr] + USHLL v.8h, v.8b, #0 pattern. Create aarch64_uload8x8 decl and rule. Uses SSHLL/USHLL inst variants at inst.zig:1477-1496. Effort: 25 min.
