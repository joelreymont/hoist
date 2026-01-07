---
title: Fix Signature.init error union
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T15:11:07.455482+02:00"
closed-at: "2026-01-04T15:12:29.719905+02:00"
---

Multiple files in codegen/opts expect Signature.init to return error union but it returns plain Signature. Files: peephole.zig:494,506, simplifybranch.zig:134,146, strength.zig:303,315,333,370,407. Need to remove 'try' from Signature.init calls.
