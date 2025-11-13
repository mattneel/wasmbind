# Repository Guidelines

## Project Structure & Module Organization
wasmbind centers on `build.zig`, which wires the reusable module `src/root.zig` into the CLI harness in `src/main.zig`. Specs and long-form decisions live in `SPEC.md`, the source of truth for WASM/TypeScript binding rules. Keep the generated `zig-out/` tree untracked. Target Zig 0.11+ and update `build.zig.zon` whenever you add dependencies.

## Build, Test, and Development Commands
- `zig build` – compiles the library and installs the `wasmbind` executable into `zig-out/bin`.
- `zig build run -- <args>` – runs the CLI after building (helpful for manual smoke tests).
- `zig build test` – executes both the module tests in `src/root.zig` and the executable tests in `src/main.zig`.
- `zig test src/root.zig` – fast cycle for a single file while iterating on APIs.
- `zig fmt src/*.zig` – formats the codebase; run before every commit.

## Coding Style & Naming Conventions
Adopt `zig fmt` defaults—four-space indents and trailing commas on multi-line lists. Use `snake_case` for functions and locals, `PascalCase` for structs/enums, and SCREAMING_SNAKE_CASE for exported constants. Keep public APIs minimal; only re-export what `src/root.zig` intends and leave helpers inside private `const` blocks.

## Testing Guidelines
Follow `std.testing` patterns in `src/root.zig` and `src/main.zig`, and name tests with short, descriptive strings (e.g., `test "basic add functionality"`). Favor deterministic checks, but when validating serialization edges mirror the fuzz example via `zig build test -- --fuzz`. Each feature PR needs at least one success-path test and one failure-path assertion; note any coverage gaps in the PR.

## Commit & Pull Request Guidelines
History uses concise imperative subjects (`Initial scaffold`), so keep that format and focus commit bodies on rationale. Push only commits that pass `zig build` and `zig build test`. PRs must summarize the Zig surface touched, reference `SPEC.md` when behavior changes, include the latest `zig build test` output, and add screenshots only when TypeScript artifacts change.

## Architecture & Configuration Notes
`SPEC.md` outlines the plan to derive bindings from a future `src/wasm.zig`. Keep new modules behind `@import("wasmbind")`, prefer `extern struct` definitions with fixed-size integers for TypeScript parity, and record deviations in SPEC before coding.
