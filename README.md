# Markdown AI Inbox

Version: `0.1.0`

A small macOS SwiftUI app that accepts messy text, files, images, PDFs, and URLs, asks a GPT model to organize the content, then saves the result as Markdown to Obsidian or Joplin.

## Storage

Choose a storage target in `Settings > Storage` before organizing or saving content.

- Obsidian: choose a local vault folder and inbox folder.
- Local Folder: choose any local folder. Markdown files and attachments are written directly into that folder.
- Joplin: enable Web Clipper in Joplin, then enter the local API port, token, and notebook name. The default port is `41184`.

## Run

From this folder:

```bash
swift run
```

The current machine has Swift command line tools but not full Xcode, so this project is a Swift Package executable. It can be packaged into a normal `.app` later with Xcode.

## Versioning

This project uses Semantic Versioning. The current version is stored in:

- `VERSION`
- `Sources/ObsidianInbox/AppVersion.swift`
- `CHANGELOG.md`

Create releases with Git tags such as:

```bash
git tag v0.1.0
git push origin main --tags
```

## Use

1. Paste text, drag files, or click `Read Clipboard`.
2. Choose your storage target in `Settings > Storage`.
3. Choose the AI provider and enter the matching API key.
   - For OpenAI, use your OpenAI secret key.
   - For AnyRouter, select `AnyRouter`, enter your AnyRouter key, and confirm the API URL matches the URL shown in your AnyRouter dashboard.
   - For custom AI endpoints, select `Custom`, enter a Bearer token and the endpoint URL.
4. Click `Organize`.
5. Review the Markdown.
6. Click `Save`.

AI organization requires a configured provider, API key, model, and endpoint.

## Testing Without a Working AI Key

You can still test:

- Text input and drag/drop extraction
- Local image OCR
- Markdown editing and saving after AI organization succeeds
- Saving Markdown into Obsidian, a local folder, or Joplin, if the target is configured

You cannot fully test the remote AI response without a valid key, model access, network access, and enough provider balance/quota.

## Supported Inputs

- Plain text
- URLs with local fetch, metadata extraction, and basic article-content extraction. Platforms such as YouTube, Xiaohongshu, and WeChat Official Account pages may still require manual review because they often restrict direct extraction.
- Images with local OCR via Apple Vision
- PDFs with text extraction via PDFKit. Scanned PDFs are not OCR processed automatically.
- Word, Excel, and PowerPoint files are saved as attachments. DOCX/XLSX/PPTX files get basic text extraction from their Office XML package; legacy DOC/XLS/PPT files are best-effort only.
- Markdown, TXT, LOG, YAML, CSV, JSON, HTML, XML, RTF

Large inputs are limited before they are sent to AI: PDFs read up to the first 50 pages and extracted text is capped at 60,000 characters. Large text files over 5 MB, Office files over 25 MB, and images over 20 MB are skipped with an explanation in the input item.

## Notes

- API keys are stored using `@AppStorage` for this MVP. A later version should move this to Keychain.
- URL article extraction is basic HTML cleanup in this version. A later version can add a Readability parser.
- Obsidian storage writes Markdown files directly to the vault folder.
- Local Folder storage writes Markdown files and attachments directly to the selected folder without creating an inbox or attachments subfolder.
- Joplin storage uses the local Web Clipper API and uploads attachments as Joplin resources.

## License

MIT
