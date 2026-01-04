//! Minimal ISLE compiler binary for Hoist
//! Invokes cranelift-isle to compile .isle files to Zig code

use std::env;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage: {} <input.isle> [<input2.isle> ...]", args[0]);
        process::exit(1);
    }

    let input_files: Vec<String> = args[1..].to_vec();

    let options = cranelift_isle::codegen::CodegenOptions {
        target: cranelift_isle::codegen::CodegenTarget::Zig,
        exclude_global_allow_pragmas: false,
        prefixes: vec![],
    };

    match cranelift_isle::compile::from_files(input_files, &options) {
        Ok(generated_code) => {
            println!("{}", generated_code);
        }
        Err(errors) => {
            eprintln!("ISLE compilation failed:");
            eprintln!("{:?}", errors);
            process::exit(1);
        }
    }
}
