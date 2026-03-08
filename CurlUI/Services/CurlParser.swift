import Foundation

struct CurlParser {

    struct ParsedRequest {
        var url: String?
        var method: HTTPMethod?
        var headers: [KeyValueEntry]
        var body: String?
    }

    static func parse(_ input: String) -> ParsedRequest? {
        let tokens = tokenize(input)
        guard tokens.first?.lowercased() == "curl" else { return nil }

        var extractedURL: String?
        var extractedMethod: String?
        var extractedHeaders: [(String, String)] = []
        var extractedBody: String?

        var i = 1
        while i < tokens.count {
            let token = tokens[i]
            switch token {
            case "-X", "--request":
                i += 1
                if i < tokens.count { extractedMethod = tokens[i].uppercased() }
            case "-H", "--header":
                i += 1
                if i < tokens.count {
                    let header = tokens[i]
                    if let colonIndex = header.firstIndex(of: ":") {
                        let key = String(header[header.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        let value = String(header[header.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        extractedHeaders.append((key, value))
                    }
                }
            case "-d", "--data", "--data-raw", "--data-binary":
                i += 1
                if i < tokens.count { extractedBody = tokens[i] }
            case "--data-urlencode":
                i += 1
                if i < tokens.count { extractedBody = tokens[i] }
            case "-u", "--user":
                i += 1
                if i < tokens.count {
                    let encoded = Data(tokens[i].utf8).base64EncodedString()
                    extractedHeaders.append(("Authorization", "Basic \(encoded)"))
                }
            case "--url":
                i += 1
                if i < tokens.count { extractedURL = tokens[i] }
            case "-k", "--insecure", "--compressed", "-L", "--location",
                 "-s", "--silent", "-S", "--show-error", "-v", "--verbose",
                 "-i", "--include":
                break
            default:
                if token.hasPrefix("http://") || token.hasPrefix("https://") {
                    extractedURL = token
                }
            }
            i += 1
        }

        let method: HTTPMethod? = {
            if let m = extractedMethod, let parsed = HTTPMethod(rawValue: m) {
                return parsed
            }
            if extractedBody != nil { return .POST }
            return nil
        }()

        var headerEntries = extractedHeaders.map { KeyValueEntry(key: $0.0, value: $0.1) }
        headerEntries.append(KeyValueEntry())

        return ParsedRequest(
            url: extractedURL,
            method: method,
            headers: headerEntries,
            body: extractedBody
        )
    }

    // MARK: - Tokenizer

    private static func tokenize(_ input: String) -> [String] {
        let cleaned = input.replacingOccurrences(of: "\\\n", with: " ")
            .replacingOccurrences(of: "\\\r\n", with: " ")

        var tokens: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false

        for char in cleaned {
            if escaped {
                current.append(char)
                escaped = false
                continue
            }

            if char == "\\" && !inSingleQuote {
                escaped = true
                continue
            }

            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                continue
            }

            if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                continue
            }

            if char.isWhitespace && !inSingleQuote && !inDoubleQuote {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }

            current.append(char)
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }
}
