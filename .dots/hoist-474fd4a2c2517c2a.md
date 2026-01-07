---
title: "machinst: buffer"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:55.688793+02:00\""
closed-at: "\"2026-01-01T16:14:07.127025+02:00\""
close-reason: Completed MachBuffer (~344 LOC) - code emission with label binding/fixups, forward/backward references, relocations, trap records with all tests passing
blocks:
  - hoist-474fd4a29115fca3
---

src/machinst/buffer.zig (~800 LOC)

Port from: cranelift/codegen/src/machinst/buffer.rs

MachBuffer - binary code emission:
- data: ArrayList(u8) - raw bytes
- labels: []LabelOffset - label positions
- pending_fixups: []Fixup - unresolved references
- traps: []TrapRecord - trap metadata

Label management:
- get_label() -> Label
- bind_label(label) - set position
- use_label(label, kind) - add fixup

Fixup kinds:
- Rel32 (x64 call/jmp)
- Rel26 (aarch64 branch)
- Abs64 (constant pool)

After emission:
- finish() -> resolves all fixups
- Returns final bytes + relocations
