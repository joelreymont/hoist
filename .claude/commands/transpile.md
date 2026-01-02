Transpile a Sleigh specification to a Binary Ninja plugin.

Arguments: $ARGUMENTS

Parse the arguments to extract:
- Architecture name (e.g., z80, ARM4_le, mips32be)

Steps:
1. Find the .slaspec file in examples/ghidra/ matching the architecture
2. Run transpiler:
   ```bash
   BINARY_NINJA_SDK=/Users/joel/Work/binaryninja-api/dev/rust ./target/release/bb -f <slaspec> --output /tmp/bebop_plugins/<arch>
   ```
3. Build the plugin with per-arch target dir to avoid lock contention:
   ```bash
   cd /tmp/bebop_plugins/<arch> && CARGO_TARGET_DIR=/tmp/bebop_target_<arch> cargo build --release > /tmp/build_<arch>.log 2>&1
   ```
   Note: Generated code has `#![deny(warnings)]` so warnings are errors for our code only.
   Note: Using per-arch target dir allows parallel builds without cargo lock contention.
   Note: VM crate is compiled per target dir; for shared VM, build sequentially with single target dir.
4. Check exit code:
   - If non-zero: Read and report /tmp/build_<arch>.log contents, then STOP
   - If zero: Continue to step 5 (do NOT read the log file on success)
5. Copy to BN plugins:
   ```bash
   cp /tmp/bebop_target_<arch>/release/lib<arch_lowercase>.dylib ~/Library/Application\ Support/Binary\ Ninja/plugins/
   ```
6. Report "SUCCESS: <arch> plugin built and installed"

## Parallel Builds

When building multiple plugins in parallel:
- Use separate target directories per architecture: `CARGO_TARGET_DIR=/tmp/bebop_target_<arch>`
- Run builds in background without monitoring output
- Only read log files when exit code is non-zero
- Each target dir compiles its own copy of VM/binaryninja crates

For sequential builds with shared compilation:
- Use single target directory: `CARGO_TARGET_DIR=/tmp/bebop_target`
- First build compiles VM (~1m41s), subsequent builds reuse it (~5s each)
- Builds must run sequentially to avoid cargo lock contention

Common architectures:
- z80: examples/ghidra/Z80/data/languages/z80.slaspec
- 6502: examples/ghidra/6502/data/languages/6502.slaspec
- ARM4_le: examples/ghidra/ARM/data/languages/ARM4_le.slaspec
- mips32be: examples/ghidra/MIPS/data/languages/mips32be.slaspec
- ppc_32_be: examples/ghidra/PowerPC/data/languages/ppc_32_be.slaspec
- 8085: examples/ghidra/8085/data/languages/8085.slaspec
- 8051: examples/ghidra/8051/data/languages/8051.slaspec
- 6809: examples/ghidra/MC6800/data/languages/6809.slaspec
- HCS08: examples/ghidra/HCS08/data/languages/HCS08.slaspec
