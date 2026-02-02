---
title: Wire ISLE Lowering Dispatch
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.558676+01:00"
blocks:
  - hoist-wire-codegen-pipeline-dfda3104
---

Context: src/codegen/compile.zig:5008; cause: lowerInstruction stub; fix: call ISLE-generated lowering for target and set ctx outputs; deps: Wire Codegen Pipeline; verification: compile simple AArch64
