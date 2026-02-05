---
title: Branch relocs
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.644940+01:00\""
closed-at: "2026-02-05T21:57:09.214403+01:00"
close-reason: Added AArch64 branch19/branch26 fixup tests validating branch patching
blocks:
  - hoist-tls-bounds-f80e490b
---

File: src/codegen/compile.zig:4513; cause: label resolution stubbed and branch patching incomplete; fix: finalize block layout + label map and patch branches/relocs; why: correct control flow.
