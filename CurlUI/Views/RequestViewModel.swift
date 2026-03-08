import Foundation
import SwiftUI

@MainActor
final class RequestViewModel: ObservableObject {
    @Published var urlString: String = ""
    @Published var selectedMethod: HTTPMethod = .GET
    @Published var headers: [HeaderEntry] = [HeaderEntry()]
    @Published var params: [ParamEntry] = [ParamEntry()]
    @Published var requestBody: String = ""
    @Published var selectedBodyType: BodyType = .none
    @Published var formDataEntries: [HeaderEntry] = [HeaderEntry()]
    @Published var urlEncodedEntries: [HeaderEntry] = [HeaderEntry()]
    @Published var graphQLQuery: String = ""
    @Published var graphQLVariables: String = ""
    @Published var binaryFilePath: String = ""
    @Published var binaryFileData: Data?
    @Published var response: APIResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedRequestTab: RequestTab = .params
    @Published var selectedResponseTab: ResponseTab = .body

    enum RequestTab: String, CaseIterable {
        case params = "Params"
        case headers = "Headers"
        case body = "Body"
    }

    enum ResponseTab: String, CaseIterable {
        case body = "Body"
        case headers = "Headers"
    }

    func addHeader() {
        headers.append(HeaderEntry())
    }

    func removeHeader(at offsets: IndexSet) {
        headers.remove(atOffsets: offsets)
        if headers.isEmpty { headers.append(HeaderEntry()) }
    }

    func addParam() {
        params.append(ParamEntry())
    }

    func removeParam(at offsets: IndexSet) {
        params.remove(atOffsets: offsets)
        if params.isEmpty { params.append(ParamEntry()) }
    }

    func addFormDataEntry() {
        formDataEntries.append(HeaderEntry())
    }

    func removeFormDataEntry(at offsets: IndexSet) {
        formDataEntries.remove(atOffsets: offsets)
        if formDataEntries.isEmpty { formDataEntries.append(HeaderEntry()) }
    }

    func addUrlEncodedEntry() {
        urlEncodedEntries.append(HeaderEntry())
    }

    func removeUrlEncodedEntry(at offsets: IndexSet) {
        urlEncodedEntries.remove(atOffsets: offsets)
        if urlEncodedEntries.isEmpty { urlEncodedEntries.append(HeaderEntry()) }
    }

    func browseBinaryFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            binaryFilePath = url.path
            binaryFileData = try? Data(contentsOf: url)
        }
    }

    func loadBinaryFile(from path: String) {
        let url = URL(fileURLWithPath: path)
        binaryFileData = try? Data(contentsOf: url)
    }

    func handleURLChange(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("curl ") else { return }
        parseCurl(trimmed)
    }

    private func parseCurl(_ input: String) {
        let tokens = tokenize(input)
        guard tokens.first?.lowercased() == "curl" else { return }

        // Reset all fields
        selectedMethod = .GET
        headers = [HeaderEntry()]
        params = [ParamEntry()]
        requestBody = ""
        selectedBodyType = .none
        formDataEntries = [HeaderEntry()]
        urlEncodedEntries = [HeaderEntry()]
        graphQLQuery = ""
        graphQLVariables = ""
        binaryFilePath = ""
        binaryFileData = nil

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
                // handled same as -d for simplicity
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
                break // ignore flags without arguments
            default:
                // If it looks like a URL, capture it
                if token.hasPrefix("http://") || token.hasPrefix("https://") {
                    extractedURL = token
                }
            }
            i += 1
        }

        // Apply parsed values
        if let url = extractedURL {
            urlString = url
        }

        if let method = extractedMethod, let m = HTTPMethod(rawValue: method) {
            selectedMethod = m
        } else if extractedBody != nil {
            selectedMethod = .POST
        }

        if !extractedHeaders.isEmpty {
            headers = extractedHeaders.map { HeaderEntry(key: $0.0, value: $0.1) }
            headers.append(HeaderEntry())
        }

        if let body = extractedBody {
            requestBody = body
            selectedBodyType = .raw
            selectedRequestTab = .body
        }
    }

    private func tokenize(_ input: String) -> [String] {
        // Remove line continuations
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

    private func buildURL() -> URL? {
        let activeParams = params.filter { !$0.key.isEmpty }
        guard var components = URLComponents(string: urlString) else { return nil }

        if !activeParams.isEmpty {
            var items = components.queryItems ?? []
            for param in activeParams {
                items.append(URLQueryItem(name: param.key, value: param.value))
            }
            components.queryItems = items
        }

        return components.url
    }

    private func buildBody() -> String? {
        switch selectedBodyType {
        case .none:
            return nil
        case .raw:
            return requestBody.isEmpty ? nil : requestBody
        case .formData:
            let pairs = formDataEntries.filter { !$0.key.isEmpty }
            guard !pairs.isEmpty else { return nil }
            return pairs.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        case .urlEncoded:
            let pairs = urlEncodedEntries.filter { !$0.key.isEmpty }
            guard !pairs.isEmpty else { return nil }
            return pairs.map {
                let key = $0.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.key
                let val = $0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value
                return "\(key)=\(val)"
            }.joined(separator: "&")
        case .graphQL:
            var dict: [String: Any] = ["query": graphQLQuery]
            if !graphQLVariables.isEmpty,
               let data = graphQLVariables.data(using: .utf8),
               let vars = try? JSONSerialization.jsonObject(with: data) {
                dict["variables"] = vars
            }
            guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return String(data: data, encoding: .utf8)
        case .binary:
            return nil
        }
    }

    func sendRequest() {
        guard let url = buildURL(), urlString.hasPrefix("http") else {
            errorMessage = "Invalid URL. Make sure it starts with http:// or https://"
            return
        }

        errorMessage = nil
        isLoading = true
        response = nil

        var headerDict = Dictionary(
            headers
                .filter { !$0.key.isEmpty }
                .map { ($0.key, $0.value) },
            uniquingKeysWith: { _, last in last }
        )

        if selectedBodyType == .urlEncoded && headerDict["Content-Type"] == nil {
            headerDict["Content-Type"] = "application/x-www-form-urlencoded"
        } else if selectedBodyType == .graphQL && headerDict["Content-Type"] == nil {
            headerDict["Content-Type"] = "application/json"
        }

        let body = buildBody()
        let rawBodyData = selectedBodyType == .binary ? binaryFileData : nil

        Task {
            do {
                let result = try await NetworkService.shared.sendRequest(
                    url: url,
                    method: selectedMethod,
                    headers: headerDict,
                    body: body,
                    bodyData: rawBodyData
                )
                self.response = result
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }
}
