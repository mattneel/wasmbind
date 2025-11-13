# Installation

wasmbind is delivered as a Zig package, so installation is just a matter of adding it to `build.zig.zon`. The steps below cover both consumers and contributors.

## Prerequisites

| Tool | Version | Purpose |
| ---- | ------- | ------- |
| Zig | 0.13.0 or later | Builds your WASM module and runs wasmbind |
| Node.js | 18+ | Runs the TypeScript tooling that consumes generated bindings |
| npm / pnpm | latest | Installs TypeScript dependencies in the examples |
| mdBook | latest | (Contributors) builds the documentation |

> ⚠️  wasmbind targets the bleeding edge of Zig. Run the nightly CI to ensure regressions are caught early.

## Creating a New Project

```bash
mkdir hello-wasmbind
cd hello-wasmbind
zig init-exe
```

Update `build.zig.zon` with the dependency:

```zig
.{
    .name = "hello-wasmbind",
    .version = "0.1.0",
    .dependencies = .{
        .wasmbind = .{
            .url = "https://github.com/mattneel/wasmbind/archive/main.tar.gz",
            .hash = "", // zig will fill this in
        },
    },
    .paths = .{""},
}
```

Fetch the dependency and allow Zig to compute the hash:

```bash
zig fetch --save wasmbind
```

Add wasmbind to `build.zig`:

```zig
const wasmbind = @import("wasmbind");
```

Now run the default build to verify everything works:

```bash
zig build test
```

## Local Development Setup

```bash
git clone https://github.com/mattneel/wasmbind.git
cd wasmbind
zig build test
```

To keep the Zig cache fresh and avoid stale artifacts:

```bash
rm -rf zig-cache ~/.cache/zig
zig build test
```

## Editor Integration

| Editor | Plugin |
| ------ | ------ |
| VS Code | [Zig Language](https://marketplace.visualstudio.com/items?itemName=ziglang.vscode-zig) |
| Neovim | [zls + nvim-lspconfig](https://github.com/zigtools/zls) |
| Emacs | [zig-mode](https://github.com/ziglang/zig-mode) |

Enable formatting on save to keep the codebase consistent:

```json
// VS Code settings.json
{
  "zig.formattingProvider": "zigfmt",
  "editor.formatOnSave": true
}
```

## Verifying the Toolchain

1. `zig version` → should match `ZIG_VERSION` in CI.
2. `node -v` → ensure v18+.
3. `npm -v` → latest stable.
4. `mdbook --version` (contributors only).

If any version mismatches occur, update the tool and re-run `zig build test` before contributing.
