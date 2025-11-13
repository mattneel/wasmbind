# Contributing Guide

Thanks for helping improve wasmbind! This project values clarity, testing, and documentation. Follow the guidelines below to keep the codebase healthy.

## Development Workflow

1. Fork the repository and clone your fork.
2. Create a feature branch (`git checkout -b feature/my-change`).
3. Make changes with small, focused commits.
4. Run the full test matrix locally (`zig build test`, `examples/chart-demo`).
5. Update documentation and examples as needed.
6. Open a Pull Request targeting `main`.

## Code Style

- Run `zig fmt` on all Zig files.
- TypeScript/JavaScript should follow the default `tsc` formatting.
- Markdown should wrap at 100 columns when practical.
- Keep functions small and well-commented where logic is non-obvious.

## Testing Requirements

- Every bug fix should include a regression test.
- New features must have coverage in `src/root.zig` or an example project.
- If you change the code generator, add/adjust tests that assert on generated snippets.
- Run `zig build test -Doptimize=ReleaseFast` before pushing to catch optimizer-specific issues.

## Documentation

- Update relevant sections in `docs/`.
- Add tutorials or troubleshooting notes if a feature may confuse users.
- Include screenshots or code samples where useful.

## Commit Messages

Use actionable, present-tense summaries:

```
Implement slice marshaling for strings
Add mdBook documentation skeleton
Fix chart demo handle allocation bug
```

## Pull Request Checklist

- [ ] Tests pass locally
- [ ] Docs updated
- [ ] Example project builds
- [ ] CI badges remain green
- [ ] No generated artifacts committed (only `.gitkeep` in `www/generated`)

## Communication

- Use GitHub Issues for bugs/feature requests.
- Label issues with `good-first-issue` when they require minimal context.
- Join discussions in the Zig community Discord (#wasm channel).

## License

By contributing you agree that your work will be licensed under the repository’s license (Apache-2.0).

We appreciate every contribution, from typo fixes to large architectural changes. Welcome aboard!
