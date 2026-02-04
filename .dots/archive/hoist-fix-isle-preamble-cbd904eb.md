---
title: Fix ISLE preamble + arg discards
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-04T17:48:03.708258+01:00\\\"\""
closed-at: "2026-02-05T00:05:20.384301+01:00"
close-reason: Fix codegen switch key/patterns; Zig 0.15
---

tools/isle_compiler.zig:31-91 duplicate Vec* aliases in base+arch preamble; src/dsl/isle/codegen/constructors.zig:110-117 unconditional _=ctx/arg triggers pointless discard when used. Fix: remove dup Vec* from arch preamble or gate by arch; emit _= only for unused args/ctx based on ruleset bindings. Why: zig build test fails; generated code must compile. Depends: hoist-elf-writer-9a1193be.
