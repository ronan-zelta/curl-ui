import Foundation
import SwiftUI

@MainActor
final class RequestViewModel: ObservableObject {
    @Published var urlString: String = "https://httpbin.org/get"
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
