# Changelog

All notable changes to this project will be documented in this file.

The format follows Keep a Changelog, and this project uses Semantic Versioning.

## [1.0.0] - 2026-07-05

### Added

- First public release of TossNote.
- Capture text, links, images, PDFs, Office documents, and local files.
- Extract readable URL content locally with safety checks.
- Run local OCR for images with Apple Vision.
- Extract text from PDFs and basic Office XML documents.
- Organize mixed captured content into editable Markdown with a configurable AI provider and prompt.
- Quick Save workflow for organizing and saving in one step.
- Save Markdown and attachments to Obsidian, a plain local folder, or Joplin Web Clipper.
- English and Simplified Chinese interface support.
- Light and dark UI themes.
- App icon assets for macOS packaging.

### Security

- Store API keys and Joplin tokens locally with lightweight encoding to avoid macOS Keychain permission prompts in unsigned builds.
- Require HTTPS for AI endpoints.
- Block unsafe local, private-network, and non-HTTP(S) web extraction targets.
- Limit large files before extraction or upload.
