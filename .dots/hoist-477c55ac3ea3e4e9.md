---
title: Port ISLE arithmetic optimization rules
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T16:06:39.132334+02:00"
closed-at: "2026-01-03T16:33:50.254001+02:00"
---

File: src/dsl/isle/opts.isle - Algebraic simplifications EXIST: x+0→x, x*1→x, x&0→0, etc. - Need: Port remaining Cranelift peephole rules (~200-300 patterns) - Examples: (x+c1)+c2→x+(c1+c2), (x<<c)>>c→x&mask, etc. - ISLE compiler integrates rules into lowering automatically - Accept: More arithmetic patterns simplified at lowering
