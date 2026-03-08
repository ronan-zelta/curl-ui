import Foundation

final class NetworkService {
    static let shared = NetworkService()
    private init() {}

    func sendRequest(
        url: URL,
        method: HTTPMethod,
        headers: [String: String],
        body: String?,
        bodyData: Data? = nil
    ) async throws -> APIResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let bodyData, method != .GET {
            request.httpBody = bodyData
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            }
        } else if let body, !body.isEmpty, method != .GET {
            request.httpBody = body.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let start = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(start)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        var responseHeaders: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let k = key as? String, let v = value as? String {
                responseHeaders[k] = v
            }
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "<binary data: \(data.count) bytes>"

        return APIResponse(
            statusCode: httpResponse.statusCode,
            headers: responseHeaders,
            body: bodyString,
            duration: duration,
            bodyData: data
        )
    }
}

enum NetworkError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received an invalid response from the server."
        }
    }
}
