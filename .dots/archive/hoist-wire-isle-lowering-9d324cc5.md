---
title: Wire ISLE Lowering Dispatch
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.558676+01:00\""
closed-at: "2026-02-06T19:08:34.235141+01:00"
close-reason: ISLE-backed lowering wired via backend lower paths.
blocks:
  - hoist-wire-codegen-pipeline-dfda3104
---

Context: src/codegen/compile.zig:5008; cause: lowerInstruction stub; fix: call ISLE-generated lowering for target and set ctx outputs; deps: Wire Codegen Pipeline; verification: compile simple AArch64
