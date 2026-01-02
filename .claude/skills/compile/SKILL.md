# Compile Skill

## When to Use

Activate when user:
- Works on compiler passes or emitter
- Generates bytecode from Sleigh specs
- Debugs bytecode output
- Asks about the IR pipeline
- Modifies pattern handling or tree building

## Commands

```bash
# Compile Sleigh spec to bytecode
zig build run -- compile <spec.slaspec> -o <output.dx>
zig build run -- compile verification/specs/ghidra/z80/data/languages/z80.slaspec -o z80.dx

# Inspect bytecode (NEVER use hexdump)
zig build run -- disasm <bytecode.dx>

# Decode to verify output
zig build run -- decode <hex> --bytecode <path.dx>
```

## IR Pipeline

```
.slaspec → parser → Symbolic IR → passes → Flat IR → Precomputed IR → Partitioned IR → bytecode.dx
```

### Compilation Passes

| Pass | File | Purpose |
|------|------|---------|
| p01 | lift.zig | AST → Symbolic IR |
| p02 | expand.zig | Expand macros/templates |
| p03 | flatten.zig | Flatten nested patterns |
| p04 | merge_context_variants.zig | Merge context-only variants |
| p05 | factor.zig | Factor common prefixes |
| p06 | inline.zig | Inline subtables |
| p07 | compute_masks.zig | Compute mask/value pairs |
| p08 | compute_length.zig | Compute instruction lengths |
| p09 | context_discrim.zig | Context discriminators |
| p10 | prefix_coalesce.zig | Coalesce prefix patterns |
| p11 | build_tree.zig | Build decision tree |
| p12 | find_discrim.zig | Find optimal discriminators |
| p13 | group_patterns.zig | Group by discriminator |
| p14 | build_switches.zig | Build switch tables |
| p15 | build_ctx_chains.zig | Context action chains |
| p16 | emit_bytecode.zig | Generate bytecode |
| p17 | link.zig | Link and finalize |

## Key Files

| Component | File |
|-----------|------|
| Parser | src/compiler/parser/parser.zig |
| Lexer | src/compiler/parser/lexer.zig |
| AST | src/compiler/parser/ast.zig |
| Symbolic IR | src/compiler/ir/symbolic.zig |
| Flat IR | src/compiler/ir/flat.zig |
| Precomputed IR | src/compiler/ir/precomputed.zig |
| Partitioned IR | src/compiler/ir/partitioned.zig |
| Emitter | src/compiler/emitter.zig |

## Pipeline Debugging

Enable IR dumps in pipeline:
```zig
const ir3 = try pipeline.compile(alloc, ir0, .{
    .dump_ir1 = true,
    .dump_ir2 = true,
    .dump_ir3 = true,
});
```

## Bytecode Format

Output is `.dx` file with:
- Header (magic, version, section offsets)
- String table
- Decision tree bytecode
- Context action bytecode

See `docs/vm.md` for VM architecture and opcode reference.

## Common Issues

| Symptom | Check |
|---------|-------|
| Wrong mask/value | p07_compute_masks.zig |
| Wrong length | p08_compute_length.zig |
| Missing pattern | p11_build_tree.zig, p12_find_discrim.zig |
| Wrong context | p09_context_discrim.zig, p15_build_ctx_chains.zig |
