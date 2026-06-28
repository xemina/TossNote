# Changelog

All notable changes to this project will be documented in this file.

The format follows Keep a Changelog, and this project uses Semantic Versioning.

## [0.1.1] - 2026-06-28

### Changed

- Reorganized source files into clearer App, Models, Services, ViewModels, Views, Components, DesignSystem, and Utilities groups.
- Rewrote README as bilingual English and Chinese documentation.
- Added privacy and secret-scanning guidance for open-source publishing.

### Removed

- Removed unused template view models, old capture model, unused UI components, and unused design-system helpers.
- Removed local macOS metadata files from the working tree.

## [0.1.0] - 2026-06-28

### Added

- Initial open-source version.
- macOS SwiftUI inbox interface for text, links, images, PDFs, Office documents, and local files.
- AI organization with OpenAI-compatible, Anthropic-compatible, Gemini, OpenRouter, AnyRouter, and custom providers.
- Local OCR for images using Apple Vision.
- Local web link fetching with metadata and article-text extraction.
- Markdown editing before save.
- Storage targets for Obsidian, local folders, and Joplin Web Clipper API.
- Attachment handling for images and documents.
