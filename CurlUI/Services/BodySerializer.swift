import Foundation

struct BodySerializer {

    static func serialize(
        bodyType: BodyType,
        rawBody: String,
        formDataEntries: [KeyValueEntry],
        urlEncodedEntries: [KeyValueEntry],
        graphQLQuery: String,
        graphQLVariables: String
    ) -> String? {
        switch bodyType {
        case .none:
            return nil
        case .raw:
            return rawBody.isEmpty ? nil : rawBody
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
}
