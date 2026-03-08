import Foundation

enum HTTPMethod: String, CaseIterable, Identifiable {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH

    var id: String { rawValue }

    var color: String {
        switch self {
        case .GET: return "green"
        case .POST: return "blue"
        case .PUT: return "orange"
        case .DELETE: return "red"
        case .PATCH: return "purple"
        }
    }
}
