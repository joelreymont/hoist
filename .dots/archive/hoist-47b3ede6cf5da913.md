---
title: Implement call direct function call
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:26:16.308583+02:00"
closed-at: "2026-01-06T19:03:15.041437+02:00"
---

File: src/codegen/compile.zig - Add lowering for call operation. Emit BL (branch-and-link) instruction with function symbol. Handle argument passing via ABI (first 8 int args in x0-x7, first 8 FP args in v0-v7, rest on stack). Handle return value in x0/v0. Critical P0.
