---
title: Lower HFA argument passing
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T08:19:17.447011+02:00\""
closed-at: "2026-01-09T12:37:31.175005+02:00"
---

In isle_helpers.zig:aarch64_call, detect HFA args using abi.classifyAggregate(). Split HFA into 2-4 FP registers (V0-V3). Extract fields, emit fmov to VN. Only HFA case (~2-4 members). File: isle_helpers.zig:3337+. ~90 min.
