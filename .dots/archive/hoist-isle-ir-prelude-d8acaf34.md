---
title: ISLE IR prelude
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:55:15.520754+01:00\\\"\""
closed-at: "2026-02-03T11:08:11.553616+01:00"
close-reason: IR prelude exists and isle_compiler prepends it
blocks:
  - hoist-wire-prelude-5c69866d
---

Context: dsl/isle; cause: lower/opts ISLE files omit opcode/IR term declarations; fix: add IR prelude generation and inject into compiler input; why: allow ISLE compile of lower/opts.
