---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:45:54.579229+02:00"
closed-at: "2026-01-01T09:05:26.886804+02:00"
close-reason: Replaced with correctly titled task
---

Use ISLE compiler to compile cranelift/codegen/src/opts/*.isle (~2280 LOC ISLE) to Zig. Create src/opts/generated.zig from arithmetic.isle, bitops.isle, cprop.isle, icmp.isle, etc. Depends on: ISLE compiler (hoist-474dea951b7c65e0), IR function (hoist-474de8b519abfca8). Files: src/opts/generated.zig (generated). Mid-end optimizations: constant propagation, algebraic simplification, etc.
