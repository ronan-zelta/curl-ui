import Foundation
import SwiftUI

@MainActor
final class RequestViewModel: ObservableObject {
    @Published var urlString: String = "https://httpbin.org/get"
    @Published var selectedMethod: HTTPMethod = .GET
    @Published var headers: [HeaderEntry] = [HeaderEntry()]
    @Published var requestBody: String = ""
    @Published var response: APIResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedResponseTab: ResponseTab = .body

    enum ResponseTab: String, CaseIterable {
        case body = "Body"
        case headers = "Headers"
    }

    var hasBody: Bool {
        selectedMethod != .GET && selectedMethod != .DELETE
    }

    func addHeader() {
        headers.append(HeaderEntry())
    }

    func removeHeader(at offsets: IndexSet) {
        headers.remove(atOffsets: offsets)
        if headers.isEmpty {
            headers.append(HeaderEntry())
        }
    }

    func sendRequest() {
        guard let url = URL(string: urlString), urlString.hasPrefix("http") else {
            errorMessage = "Invalid URL. Make sure it starts with http:// or https://"
            return
        }

        errorMessage = nil
        isLoading = true
        response = nil

        let headerDict = Dictionary(
            headers
                .filter { !$0.key.isEmpty }
                .map { ($0.key, $0.value) },
            uniquingKeysWith: { _, last in last }
        )

        Task {
            do {
                let result = try await NetworkService.shared.sendRequest(
                    url: url,
                    method: selectedMethod,
                    headers: headerDict,
                    body: hasBody ? requestBody : nil
                )
                self.response = result
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }
}
