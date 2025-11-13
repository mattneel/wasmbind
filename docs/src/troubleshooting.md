# Troubleshooting

Common issues and their solutions.

## `entry symbol not defined (_start)`

The WASM target must have no entry point. Ensure `wasmbind.generate` sets `wasm_lib.entry = .disabled` (handled automatically). If you bypass wasmbind, pass `-fno-entry` to Zig.

## `wasm_exports` compile errors

If the contract fails to compile for the host (during codegen), the runner will error with messages referencing `wasm_exports`. Fix the underlying Zig compile error—often missing imports or platform-specific code.

## `std.heap.WasmPageAllocator` missing

Older Zig versions lack `std.heap.wasm_allocator`. Upgrade to 0.13.0+ or backport the allocator into your project and tweak the generator.

## Slice marshaling bugs

Symptoms: garbled strings, incorrect array lengths. Verify that your methods use `[]const T` (not raw pointers) and that TypeScript passes the correct typed array. Use `console.log(ptr, len)` inside Zig to debug.

## TypeScript cannot find generated files

Make sure `output_dir` points to a location under your project (e.g., `www/generated`). Add that path to `tsconfig.json`’s `include` array.

## wasm-validate failures

Run `wasm-objdump -x module.wasm` to inspect exports. Ensure your build target is `wasm32-freestanding` and that no native syscalls slip in (`std.io` functions require `env` imports).

## Large WASM binaries

- Use `-Doptimize=ReleaseSmall`
- Strip debug info (`zig build -Dstrip=true`)
- Run `wasm-opt -Oz`
- Remove unused exports from your contract

## TypeScript bundler complaints

If your bundler doesn’t like `.ts` imports from `bindings.ts`, configure it to treat the file as ES module (most bundlers do this automatically). When using CommonJS, transpile the bindings with `tsc` first.

## `zig build` hangs

Ensure the codegen runner isn’t waiting for input. It only reads CLI args; no prompts should appear. If it seems stuck, run with `-Dwasmbind-debug=true` (future flag) or insert debug prints.

## Getting Help

- Search existing issues at https://github.com/mattneel/wasmbind/issues
- Open a new issue with reproduction steps.
- Mention Zig version, host OS, and the failing command output.

Happy debugging!
