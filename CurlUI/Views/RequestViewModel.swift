import Foundation
import SwiftUI

@MainActor
final class RequestViewModel: ObservableObject {
    @Published var urlString: String = ""
    @Published var selectedMethod: HTTPMethod = .GET
    @Published var headers: [KeyValueEntry] = [KeyValueEntry()]
    @Published var params: [KeyValueEntry] = [KeyValueEntry()]
    @Published var requestBody: String = ""
    @Published var selectedBodyType: BodyType = .none
    @Published var formDataEntries: [KeyValueEntry] = [KeyValueEntry()]
    @Published var urlEncodedEntries: [KeyValueEntry] = [KeyValueEntry()]
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

    // MARK: - Key-Value List Helpers

    private func addEntry(to list: inout [KeyValueEntry]) {
        list.append(KeyValueEntry())
    }

    private func removeEntry(from list: inout [KeyValueEntry], at offsets: IndexSet) {
        list.remove(atOffsets: offsets)
        if list.isEmpty { list.append(KeyValueEntry()) }
    }

    func addHeader() { addEntry(to: &headers) }
    func removeHeader(at offsets: IndexSet) { removeEntry(from: &headers, at: offsets) }

    func addParam() { addEntry(to: &params) }
    func removeParam(at offsets: IndexSet) { removeEntry(from: &params, at: offsets) }

    func addFormDataEntry() { addEntry(to: &formDataEntries) }
    func removeFormDataEntry(at offsets: IndexSet) { removeEntry(from: &formDataEntries, at: offsets) }

    func addUrlEncodedEntry() { addEntry(to: &urlEncodedEntries) }
    func removeUrlEncodedEntry(at offsets: IndexSet) { removeEntry(from: &urlEncodedEntries, at: offsets) }

    // MARK: - Binary File

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

    // MARK: - Curl Paste Detection

    func handleURLChange(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("curl ") else { return }
        applyCurlParse(trimmed)
    }

    private func applyCurlParse(_ input: String) {
        guard let parsed = CurlParser.parse(input) else { return }

        selectedMethod = .GET
        headers = [KeyValueEntry()]
        params = [KeyValueEntry()]
        requestBody = ""
        selectedBodyType = .none
        formDataEntries = [KeyValueEntry()]
        urlEncodedEntries = [KeyValueEntry()]
        graphQLQuery = ""
        graphQLVariables = ""
        binaryFilePath = ""
        binaryFileData = nil

        if let url = parsed.url {
            urlString = url
        }

        if let method = parsed.method {
            selectedMethod = method
        }

        if parsed.headers.count > 1 {
            headers = parsed.headers
        }

        if let body = parsed.body {
            requestBody = body
            selectedBodyType = .raw
            selectedRequestTab = .body
        }
    }

    // MARK: - Send Request

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

        let body = BodySerializer.serialize(
            bodyType: selectedBodyType,
            rawBody: requestBody,
            formDataEntries: formDataEntries,
            urlEncodedEntries: urlEncodedEntries,
            graphQLQuery: graphQLQuery,
            graphQLVariables: graphQLVariables
        )
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

    // MARK: - URL Builder

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
}
