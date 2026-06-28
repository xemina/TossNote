# Changelog

All notable changes to this project will be documented in this file.

The format follows Keep a Changelog, and this project uses Semantic Versioning.

## [1.1.0] - 2026-06-28

### Added

- Added a Quick Save workflow that organizes captured input and saves the generated Markdown in one action.
- Added Appearance settings for English/Simplified Chinese preference and light/dark mode.
- Added a calmer moss-green visual accent for the app chrome and primary actions.

## [1.0.0] - 2026-06-28

### Added

- First public release of Markdown AI Inbox.
- Includes capture, local extraction, AI organization, editable Markdown preview, Obsidian save, local folder save, and Joplin save.
- Includes Keychain-based credential storage and guarded public-web URL extraction.

## [0.1.2] - 2026-06-28

### Security

- Moved AI provider API keys from UserDefaults to macOS Keychain with automatic migration of existing keys.
- Moved the Joplin Web Clipper token from AppStorage/UserDefaults to macOS Keychain.
- Required HTTPS for AI endpoints to avoid sending API keys over unencrypted connections.
- Blocked web extraction for localhost, `.local`, private-network, link-local, and non-HTTP(S) URLs.
- Added redirect safety checks and an ephemeral URLSession for web extraction.
- Added request timeouts and a 50 MB per-attachment upload limit for Joplin saves.

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
