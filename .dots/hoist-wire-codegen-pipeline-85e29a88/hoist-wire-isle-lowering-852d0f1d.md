---
title: Wire ISLE Lowering Dispatch
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.426772+01:00"
---

Context: src/codegen/compile.zig:5008; cause: lowerInstruction stub; fix: call ISLE-generated lowering for target and set ctx outputs; deps: hoist-wire-codegen-pipeline-85e29a88; verification: compile simple AArch64
