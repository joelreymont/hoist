---
title: Port ISLE bitwise optimization rules
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T14:54:26.542511+02:00"
closed-at: "2026-01-03T17:19:17.965852+02:00"
---

File: src/codegen/opts/instcombine.zig - Port Cranelift bitops.isle patterns: x&0→0, x&-1→x, x&x→x, x|0→x, x|-1→-1, x|x→x, x^0→x, x^x→0, ~(x&y)→~x|~y, ~(x|y)→~x&~y, shift identities - Accept: Bitwise identities applied - Depends: none
