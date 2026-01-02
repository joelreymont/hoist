List all available Ghidra Sleigh architectures.

Find all .slaspec files in examples/ghidra/ and categorize them:
1. List total count
2. Group by processor family (ARM, MIPS, x86, etc.)
3. Note which ones have known issues (RefCell errors, crashes)

Known issues (from CONTEXT.md):
- RefCell errors: ARM6/7/8, MIPS variants, AVR8, Xtensa
- x86/x86-64: Recursive context patterns
