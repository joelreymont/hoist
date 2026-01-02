Verify all architecture plugins against IDA/Capstone references.

Run: `python3 tools/verify.py`

This will test all architectures with pre-built reference files:
- z80, 8085, 6502, 6809, 8051, HCS08 (IDA reference)
- ARM4_le, ARM5_le (IDA + BN built-in armv7)
- mips32be (IDA + BN built-in mips32)
- ppc_32_be (IDA + BN built-in ppc)
- CR16C (Capstone fallback - IDA doesn't support)

Report summary:
- Total architectures tested
- PASS: 100% match
- PARTIAL: >80% match
- FAIL: <80% match
- ERROR: Plugin or reference missing

For detailed output on failures, add `--verbose` flag.
