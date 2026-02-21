---
title: rewrite fast add-imm mov-rr
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T21:21:13.719672+01:00\\\"\""
closed-at: "2026-02-21T21:24:14.950840+01:00"
close-reason: "discarded: repeat-9 regression on large(1000)"
---

Context: rewriteAArch64SimpleFast only accepts mov_imm/add_rr/ret; likely misses hot arithmetic streams using add_imm/mov_rr; fix: extend simple fast mapper to cover add_imm and mov_rr while keeping no-spill assumptions.
