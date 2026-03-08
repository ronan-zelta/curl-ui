import Foundation

enum HTTPMethod: String, CaseIterable, Identifiable {
    case GET
    case POST
    case PUT
    case DELETE
    case PATCH

    var id: String { rawValue }
}
