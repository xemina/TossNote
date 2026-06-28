# Markdown AI Inbox

Version: `1.0.0`

Markdown AI Inbox is a macOS SwiftUI app for collecting text, links, images, PDFs, Office documents, and other local files, then using an AI provider to turn the captured content into editable Markdown. The final Markdown can be saved to Obsidian, a local folder, or Joplin.

中文说明见下方：[中文](#中文)

## Features

- Capture text from clipboard, manual input, drag-and-drop files, and local file picker.
- Extract readable content from URLs with local fetching and basic article cleanup.
- Run local OCR for images with Apple Vision.
- Extract text from PDFs with PDFKit. Scanned PDFs are not OCR processed automatically.
- Extract basic text from DOCX, XLSX, and PPTX Office XML files.
- Send the combined captured content to an AI provider for Markdown organization.
- Edit the generated Markdown before saving.
- Save Markdown and attachments to Obsidian, a plain local folder, or Joplin Web Clipper.

## Supported Inputs

- Plain text
- URLs and web pages
- Images: PNG, JPG, JPEG, HEIC, GIF, TIFF
- PDFs
- Office documents: DOCX, XLSX, PPTX, plus best-effort support for legacy DOC, XLS, PPT attachments
- Markdown, TXT, LOG, YAML, CSV, JSON, HTML, XML, RTF

Large inputs are limited before they are sent to AI:

- PDFs read up to the first 50 pages.
- Extracted text is capped at 60,000 characters.
- Text files over 5 MB, Office files over 25 MB, and images over 20 MB are skipped with an explanation in the input item.

## Storage Targets

Choose a target in `Settings > Storage` before organizing or saving content.

- Obsidian: choose your vault folder and an inbox folder inside the vault. Attachments are saved with the note and linked from Markdown.
- Local Folder: choose any local folder. Markdown files and attachments are written directly into that folder.
- Joplin: enable Web Clipper in Joplin, then enter the local API port, token, and notebook name. The default port is `41184`.

## AI Configuration

Choose an AI provider in `Settings > AI`, then configure:

- API key
- Model name
- Endpoint URL
- Custom API format when using a custom provider

AI organization requires a configured provider, API key, model, and endpoint. API keys are stored locally in macOS Keychain.

## Prompt Configuration

The prompt in `Settings > Prompt` controls how the app asks AI to organize captured input. You can customize:

- The system prompt
- The Markdown title format
- Reset back to the built-in default prompt

The app sends the captured input content to AI and expects Markdown in return. The generated Markdown remains editable before saving.

## Project Structure

```text
Sources/ObsidianInbox/
  App/            App entry point and version metadata
  Components/     Reusable UI components
  DesignSystem/   Shared colors, typography, spacing, buttons, and surfaces
  Models/         Data models and storage target definitions
  Services/       AI clients, content extraction, and storage writers
  Utilities/      Shared extensions
  ViewModels/     App view models
  Views/          SwiftUI screens and panels
```

## Run

```bash
swift run
```

This project is currently a Swift Package executable. It can be packaged into a normal `.app` later with Xcode.

## Build

```bash
swift build
```

## Versioning

This project uses Semantic Versioning.

The current version is stored in:

- `VERSION`
- `Sources/ObsidianInbox/App/AppVersion.swift`
- `CHANGELOG.md`

Create releases with Git tags:

```bash
git tag v1.0.0
git push origin main --tags
```

## Privacy And Security

- API keys and the Joplin Web Clipper token are stored in macOS Keychain.
- Existing API keys or Joplin tokens previously stored in UserDefaults are migrated to Keychain and removed from UserDefaults when loaded.
- AI endpoints must use HTTPS, so provider API keys are not sent over plain HTTP.
- Web extraction only fetches public `http` or `https` URLs. Localhost, `.local`, private-network, link-local, and non-HTTP(S) URLs are blocked.
- Web extraction uses an ephemeral URLSession and blocks redirects to unsafe local or private-network addresses.
- Large files are limited before extraction; Joplin uploads are limited to 50 MB per attachment.
- Do not commit API keys, local provider tokens, Obsidian vault paths, Joplin tokens, or local assistant configuration.
- `.gitignore` excludes environment files, secret files, macOS metadata, build artifacts, and SwiftPM local metadata.
- Before publishing, run a secret scan such as:

```bash
rg -n "sk-[A-Za-z0-9]|API_KEY|TOKEN|/Users/" .
```

## License

MIT

---

# 中文

Markdown AI Inbox 是一个 macOS SwiftUI 应用，用来收集文本、链接、图片、PDF、Office 文档和本地文件，然后调用 AI 把这些内容整理成可编辑的 Markdown。最终 Markdown 可以保存到 Obsidian、本地文件夹或 Joplin。

当前版本：`1.0.0`

## 功能

- 支持剪贴板、手动输入、文件拖拽和本地文件选择。
- 支持本地抓取 URL 内容，并做基础正文提取。
- 使用 Apple Vision 对图片做本地 OCR。
- 使用 PDFKit 提取 PDF 文本。扫描版 PDF 当前不会自动做整页 OCR。
- 对 DOCX、XLSX、PPTX 做基础文本提取。
- 把汇总后的输入内容发送给 AI，由 AI 返回 Markdown。
- 保存前可以直接编辑 Markdown。
- 支持保存到 Obsidian、本地文件夹和 Joplin Web Clipper。

## 支持的输入

- 普通文本
- URL 和网页
- 图片：PNG、JPG、JPEG、HEIC、GIF、TIFF
- PDF
- Office 文档：DOCX、XLSX、PPTX；旧格式 DOC、XLS、PPT 作为附件保存，文本提取为 best-effort
- Markdown、TXT、LOG、YAML、CSV、JSON、HTML、XML、RTF

大文件会在发送给 AI 前做限制：

- PDF 最多读取前 50 页。
- 提取文本最多保留 60,000 字符。
- 超过 5 MB 的文本文件、超过 25 MB 的 Office 文件、超过 20 MB 的图片会跳过，并在 item 中提示原因。

## 存储目标

使用前请先在 `Settings > Storage` 里选择存储方式。

- Obsidian：选择你的 vault 目录和 vault 内的 inbox 目录。附件会随 Markdown 保存并在 Markdown 中关联。
- Local Folder：选择任意本地目录。Markdown 和附件会直接写入该目录，不额外创建 inbox 层级。
- Joplin：在 Joplin 中开启 Web Clipper，然后填写本地端口、token 和 notebook 名称。默认端口是 `41184`。

## AI 配置

在 `Settings > AI` 中选择服务商，然后配置：

- API key
- 模型名称
- Endpoint URL
- 使用自定义服务商时选择 API 格式

AI 整理功能需要服务商、API key、模型和 endpoint 都配置正确。API key 会保存在 macOS Keychain 中。

## Prompt 配置

`Settings > Prompt` 里的 prompt 会决定应用如何让 AI 整理输入内容。你可以自定义：

- 系统 prompt
- Markdown 标题格式
- 一键恢复系统默认 prompt

应用会把 input item 汇总后的内容发送给 AI，并期望 AI 返回 Markdown。返回后的 Markdown 可以继续编辑，保存时会保存编辑后的版本。

## 项目结构

```text
Sources/ObsidianInbox/
  App/            应用入口和版本信息
  Components/     可复用 UI 组件
  DesignSystem/   颜色、排版、间距、按钮和 surface 样式
  Models/         数据模型和存储目标定义
  Services/       AI 客户端、内容提取、存储写入
  Utilities/      通用扩展
  ViewModels/     ViewModel
  Views/          SwiftUI 页面和面板
```

## 运行

```bash
swift run
```

当前项目是 Swift Package executable。之后可以用 Xcode 打包成标准 `.app`。

## 构建

```bash
swift build
```

## 版本管理

项目使用 Semantic Versioning。

当前版本号维护在：

- `VERSION`
- `Sources/ObsidianInbox/App/AppVersion.swift`
- `CHANGELOG.md`

发布版本时使用 Git tag：

```bash
git tag v1.0.0
git push origin main --tags
```

## 隐私和安全

- API key 和 Joplin Web Clipper token 会保存到 macOS Keychain。
- 旧版本如果曾把 API key 或 Joplin token 存在 UserDefaults，应用读取时会自动迁移到 Keychain 并删除旧明文值。
- AI endpoint 必须使用 HTTPS，避免 API key 通过明文 HTTP 发送。
- 网页提取只允许公网 `http` 或 `https` URL。localhost、`.local`、内网地址、链路本地地址和非 HTTP(S) URL 会被阻止。
- 网页提取使用临时 URLSession，并会阻止 redirect 跳转到本地或内网地址。
- 大文件会在提取前限制；Joplin 单个附件上传限制为 50 MB。
- 不要提交 API key、本地服务商 token、Obsidian 私人目录、Joplin token 或本地助手配置。
- `.gitignore` 已忽略环境文件、密钥文件、macOS 元数据、构建产物和 SwiftPM 本地元数据。
- 发布前建议运行敏感信息扫描：

```bash
rg -n "sk-[A-Za-z0-9]|API_KEY|TOKEN|/Users/" .
```

## License

MIT
