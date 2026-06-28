# Contributing

Thanks for considering a contribution.

## Development

Requirements:

- macOS 13 or later
- Swift 6 toolchain

Build locally:

```bash
swift build
```

Run locally:

```bash
swift run
```

## Pull Requests

- Keep changes focused and scoped.
- Run `swift build` before opening a pull request.
- Do not commit API keys, local vault paths, local Joplin tokens, or generated build output.
- Update `CHANGELOG.md` when user-facing behavior changes.

## Versioning

This project uses Semantic Versioning:

- `MAJOR` for incompatible changes
- `MINOR` for new backwards-compatible features
- `PATCH` for bug fixes

The current version is stored in `VERSION` and `AppVersion.current`.

