Verify a single architecture plugin against IDA/Capstone reference.

Arguments: $ARGUMENTS

Parse arguments to extract the architecture name (e.g., z80, ARM4_le, mips32be).

Run: `python3 tools/verify.py --arch <arch> --verbose`

The verify.py script will:
1. Use pre-built reference files from examples/binaries/
2. Compare Bebop plugin disassembly against IDA (primary) or Capstone (fallback)
3. For BN built-in architectures (armv7, mips32, ppc), also compare disassembly and LLIL
4. Isolate the plugin for fast BN loading (moves other plugins temporarily)

Report:
- IDA/Capstone match percentage
- BN built-in comparison results (if applicable)
- Any mnemonic or operand mismatches

Reference mappings:
| Bebop Arch | IDA Processor | BN Built-in |
|------------|---------------|-------------|
| z80        | z80           | -           |
| 8085       | z80           | -           |
| 6502       | m65           | -           |
| 6809       | mc8           | -           |
| 8051       | 8051          | -           |
| HCS08      | hcs08         | -           |
| ARM4_le    | arm           | armv7       |
| ARM5_le    | arm           | armv7       |
| mips32be   | mips          | mips32      |
| ppc_32_be  | ppc           | ppc         |
