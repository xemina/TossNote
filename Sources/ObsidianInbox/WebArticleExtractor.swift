import Foundation

struct WebArticle {
    let title: String?
    let siteName: String?
    let author: String?
    let publishedAt: String?
    let excerpt: String?
    let contentText: String
    let extractionStatus: String
}

struct WebArticleExtractor {
    func extract(html: String, url: URL) -> WebArticle {
        let title = firstMetadataValue(
            in: html,
            keys: ["og:title", "twitter:title", "title"]
        ) ?? htmlTitle(in: html)
        let siteName = firstMetadataValue(in: html, keys: ["og:site_name", "application-name"])
        let author = firstMetadataValue(in: html, keys: ["author", "article:author", "parsely-author"])
        let publishedAt = firstMetadataValue(
            in: html,
            keys: ["article:published_time", "datePublished", "publishdate", "pubdate", "date"]
        )
        let excerpt = firstMetadataValue(
            in: html,
            keys: ["description", "og:description", "twitter:description"]
        )

        let contentText = bestContentText(from: html)
        let status = contentText.count < 500
            ? "partial_or_metadata_only"
            : "content_extracted"

        return WebArticle(
            title: cleaned(title),
            siteName: cleaned(siteName) ?? url.host,
            author: cleaned(author),
            publishedAt: cleaned(publishedAt),
            excerpt: cleaned(excerpt),
            contentText: contentText,
            extractionStatus: status
        )
    }

    private func bestContentText(from html: String) -> String {
        let prepared = removeNonContentBlocks(from: html)
        let candidates = candidateHTMLBlocks(from: prepared)

        let best = candidates
            .map { block -> (text: String, score: Int) in
                let text = htmlToText(block)
                return (text, score(text: text, html: block))
            }
            .filter { !$0.text.isEmpty }
            .max { $0.score < $1.score }

        if let best, best.score > 0 {
            return best.text
        }

        if let body = firstMatch(in: prepared, pattern: #"(?is)<body\b[^>]*>(.*?)</body>"#) {
            return htmlToText(body)
        }

        return htmlToText(prepared)
    }

    private func candidateHTMLBlocks(from html: String) -> [String] {
        var blocks: [String] = []
        let patterns = [
            #"(?is)<article\b[^>]*>.*?</article>"#,
            #"(?is)<main\b[^>]*>.*?</main>"#,
            #"(?is)<section\b[^>]*(?:id|class)\s*=\s*["'][^"']*(?:article|content|post|entry|main|body|detail|rich_media_content)[^"']*["'][^>]*>.*?</section>"#,
            #"(?is)<div\b[^>]*(?:id|class)\s*=\s*["'][^"']*(?:article|content|post|entry|main|body|detail|rich_media_content)[^"']*["'][^>]*>.*?</div>"#
        ]

        for pattern in patterns {
            blocks.append(contentsOf: matches(in: html, pattern: pattern))
        }

        if blocks.isEmpty {
            blocks.append(html)
        }

        return blocks
    }

    private func score(text: String, html: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        let paragraphCount = matches(in: html, pattern: #"(?is)<p\b[^>]*>"#).count
        let linkText = matches(in: html, pattern: #"(?is)<a\b[^>]*>.*?</a>"#)
            .map(htmlToText)
            .joined(separator: " ")
        let navigationPenalty = ["cookie", "subscribe", "sign in", "login", "advertisement", "related articles"]
            .filter { trimmed.lowercased().contains($0) }
            .count * 200

        return trimmed.count + paragraphCount * 80 - linkText.count * 2 - navigationPenalty
    }

    private func removeNonContentBlocks(from html: String) -> String {
        var output = html
        let patterns = [
            #"(?is)<script\b.*?</script>"#,
            #"(?is)<style\b.*?</style>"#,
            #"(?is)<noscript\b.*?</noscript>"#,
            #"(?is)<svg\b.*?</svg>"#,
            #"(?is)<nav\b.*?</nav>"#,
            #"(?is)<footer\b.*?</footer>"#,
            #"(?is)<form\b.*?</form>"#,
            #"(?is)<aside\b.*?</aside>"#
        ]

        for pattern in patterns {
            output = output.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        return output
    }

    private func htmlToText(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(
            of: #"(?i)<\s*(br|p|div|section|article|main|li|tr|h[1-6])\b[^>]*>"#,
            with: "\n",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: #"(?is)<[^>]+>"#, with: " ", options: .regularExpression)
        text = decodeHTMLEntities(text)
        text = text.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\n[ \t]+"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstMetadataValue(in html: String, keys: [String]) -> String? {
        for key in keys {
            let escapedKey = NSRegularExpression.escapedPattern(for: key)
            let patterns = [
                #"(?is)<meta\b[^>]*(?:name|property|itemprop)\s*=\s*["']\#(escapedKey)["'][^>]*content\s*=\s*["']([^"']+)["'][^>]*>"#,
                #"(?is)<meta\b[^>]*content\s*=\s*["']([^"']+)["'][^>]*(?:name|property|itemprop)\s*=\s*["']\#(escapedKey)["'][^>]*>"#
            ]

            for pattern in patterns {
                if let value = firstMatch(in: html, pattern: pattern) {
                    return decodeHTMLEntities(value)
                }
            }
        }

        return nil
    }

    private func htmlTitle(in html: String) -> String? {
        firstMatch(in: html, pattern: #"(?is)<title\b[^>]*>(.*?)</title>"#)
            .map(decodeHTMLEntities)
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let matchRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[matchRange])
    }

    private func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range(at: 0), in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = decodeHTMLEntities(value)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var output = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")

        output = output.replacingOccurrences(
            of: #"&#(\d+);"#,
            with: { match in
                guard let value = Int(match), let scalar = UnicodeScalar(value) else {
                    return "&#\(match);"
                }
                return String(Character(scalar))
            },
            options: .regularExpression
        )

        return output
    }
}

private extension String {
    func replacingOccurrences(
        of pattern: String,
        with transform: (String) -> String,
        options: String.CompareOptions
    ) -> String {
        guard options.contains(.regularExpression),
              let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }

        let nsRange = NSRange(startIndex..<endIndex, in: self)
        var output = self

        for match in regex.matches(in: self, range: nsRange).reversed() {
            guard match.numberOfRanges > 1,
                  let wholeRange = Range(match.range(at: 0), in: output),
                  let captureRange = Range(match.range(at: 1), in: self) else {
                continue
            }

            let capture = String(self[captureRange])
            output.replaceSubrange(wholeRange, with: transform(capture))
        }

        return output
    }
}
