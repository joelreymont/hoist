---
title: Mach-O writer
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-02T23:57:14.620784+01:00\""
closed-at: "2026-02-06T11:17:59.032161+01:00"
close-reason: Validated Mach-O writer implementation/tests; load cmds, sections, relocs, symtab are implemented in src/object/macho.zig.
blocks:
  - hoist-coff-writer-76e95f19
---

File: src/object/macho.zig:194; cause: load commands/sections/symtab TODO; fix: implement Mach-O commands, section layout, reloc/symtab; why: valid Mach-O output.
