---
title: Implement basic VCodeBuilder integration in compile.zig lower()
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:09:43.455894+02:00"
closed-at: "2026-01-05T16:11:35.224392+02:00"
---

File: src/codegen/compile.zig:352-356 - VCodeBuilder exists in src/machinst/vcode_builder.zig and is now exported. Need to: (1) Create VCodeBuilder instance with target Inst type, (2) Wire it into lower() function, (3) Handle basic lowering flow even if ISLE rules are stubbed. This will allow compile pipeline to progress past lowering step. Currently lower() just returns immediately with stub comment.
