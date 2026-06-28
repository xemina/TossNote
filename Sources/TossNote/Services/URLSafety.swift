import Foundation

enum URLSafety {
    static func isAllowedPublicWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = normalizedHost(url.host),
              !host.isEmpty else {
            return false
        }

        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
            return false
        }

        if let octets = ipv4Octets(host) {
            return isPublicIPv4(octets)
        }

        if isIPv6Literal(host) {
            return isPublicIPv6(host)
        }

        return host.contains(".")
    }

    static func isSecureRemoteEndpoint(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && normalizedHost(url.host) != nil
    }

    private static func normalizedHost(_ host: String?) -> String? {
        host?
            .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }

    private static func ipv4Octets(_ host: String) -> [Int]? {
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return nil }
        let octets = parts.compactMap { part -> Int? in
            guard let value = Int(part), (0...255).contains(value) else { return nil }
            return value
        }
        return octets.count == 4 ? octets : nil
    }

    private static func isPublicIPv4(_ octets: [Int]) -> Bool {
        let first = octets[0]
        let second = octets[1]

        if first == 0 || first == 10 || first == 127 || first >= 224 {
            return false
        }
        if first == 100 && (64...127).contains(second) {
            return false
        }
        if first == 169 && second == 254 {
            return false
        }
        if first == 172 && (16...31).contains(second) {
            return false
        }
        if first == 192 && second == 168 {
            return false
        }

        return true
    }

    private static func isIPv6Literal(_ host: String) -> Bool {
        host.contains(":")
    }

    private static func isPublicIPv6(_ host: String) -> Bool {
        let lowercased = host.lowercased()
        if lowercased == "::1" || lowercased == "::" {
            return false
        }
        if lowercased.hasPrefix("fe80:")
            || lowercased.hasPrefix("fc")
            || lowercased.hasPrefix("fd")
            || lowercased.hasPrefix("ff") {
            return false
        }
        if lowercased.hasPrefix("::ffff:127.")
            || lowercased.hasPrefix("::ffff:10.")
            || lowercased.hasPrefix("::ffff:192.168.") {
            return false
        }

        return true
    }
}

final class SafeWebRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url, URLSafety.isAllowedPublicWebURL(url) else {
            completionHandler(nil)
            return
        }

        completionHandler(request)
    }
}
