---
title: Add ELF Symtab/Strtab/Rela
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.468888+01:00"
---

Context: src/object/elf.zig:191; cause: missing sym/str/rela sections; fix: emit symtab/strtab/shstrtab and rela sections; deps: hoist-add-elf-section-e42df650; verification: llvm-readobj shows symbols+relocs
