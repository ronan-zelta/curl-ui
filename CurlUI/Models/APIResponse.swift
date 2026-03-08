import Foundation

struct APIResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: String
    let duration: TimeInterval
    let bodyData: Data

    var formattedBody: String {
        guard let json = try? JSONSerialization.jsonObject(with: bodyData),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8)
        else {
            return body
        }
        return str
    }

    var statusCategory: StatusCategory {
        switch statusCode {
        case 200..<300: return .success
        case 300..<400: return .redirect
        case 400..<500: return .clientError
        case 500..<600: return .serverError
        default: return .unknown
        }
    }

    enum StatusCategory {
        case success, redirect, clientError, serverError, unknown
    }
}
