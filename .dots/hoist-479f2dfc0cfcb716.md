---
title: Update inst_predicates dot to depend on Opcode
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T09:40:57.129221+02:00"
closed-at: "2026-01-05T09:41:51.543282+02:00"
---

File: Update hoist-479f25190eb7b4c5 description to note dependency on hoist-479f2d8b28dc1098 (Opcode property methods). inst_predicates requires Opcode.is_call/is_branch/can_trap/etc. Root cause: dependency not explicit. Fix: Block inst_predicates on Opcode properties completion.
