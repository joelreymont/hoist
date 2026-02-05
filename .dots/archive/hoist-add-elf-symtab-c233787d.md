---
title: Add ELF Symtab/Strtab/Rela
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.587606+01:00\""
closed-at: "2026-02-05T21:54:22.034280+01:00"
close-reason: ELF symtab/strtab/rela emission covered by writer tests
blocks:
  - hoist-add-elf-section-d90d3c17
---

Context: src/object/elf.zig:191; cause: missing sym/str/rela sections; fix: emit symtab/strtab/shstrtab and rela sections; deps: Add ELF Section Layout; verification: llvm-readobj shows symbols+relocs
