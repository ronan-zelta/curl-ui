import Foundation

enum BodyType: String, CaseIterable, Identifiable {
    case none = "none"
    case formData = "form-data"
    case urlEncoded = "x-www-form-urlencoded"
    case raw = "raw"
    case binary = "binary"
    case graphQL = "GraphQL"

    var id: String { rawValue }
}
