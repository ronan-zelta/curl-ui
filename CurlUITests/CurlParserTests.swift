import XCTest
@testable import CurlUI

final class CurlParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func testReturnsNilForNonCurlInput() {
        XCTAssertNil(CurlParser.parse("not a curl command"))
        XCTAssertNil(CurlParser.parse("wget https://example.com"))
        XCTAssertNil(CurlParser.parse(""))
    }

    func testParsesSimpleGET() {
        let result = CurlParser.parse("curl https://api.example.com/users")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.url, "https://api.example.com/users")
        XCTAssertNil(result?.method) // no explicit method, no body → nil
        XCTAssertNil(result?.body)
    }

    func testParsesExplicitGET() {
        let result = CurlParser.parse("curl -X GET https://api.example.com/users")

        XCTAssertEqual(result?.url, "https://api.example.com/users")
        XCTAssertEqual(result?.method, .GET)
    }

    // MARK: - HTTP Methods

    func testParsesExplicitPOST() {
        let result = CurlParser.parse("curl -X POST https://api.example.com/users")

        XCTAssertEqual(result?.method, .POST)
        XCTAssertEqual(result?.url, "https://api.example.com/users")
    }

    func testParsesLongFormRequest() {
        let result = CurlParser.parse("curl --request PUT https://api.example.com/users/1")

        XCTAssertEqual(result?.method, .PUT)
    }

    func testParsesDELETE() {
        let result = CurlParser.parse("curl -X DELETE https://api.example.com/users/1")

        XCTAssertEqual(result?.method, .DELETE)
    }

    func testParsesPATCH() {
        let result = CurlParser.parse("curl -X PATCH https://api.example.com/users/1")

        XCTAssertEqual(result?.method, .PATCH)
    }

    // MARK: - Headers

    func testParsesSingleHeader() {
        let result = CurlParser.parse("curl -H 'Content-Type: application/json' https://api.example.com")

        let headers = result!.headers.filter { !$0.key.isEmpty }
        XCTAssertEqual(headers.count, 1)
        XCTAssertEqual(headers[0].key, "Content-Type")
        XCTAssertEqual(headers[0].value, "application/json")
    }

    func testParsesMultipleHeaders() {
        let result = CurlParser.parse("""
            curl -H 'Content-Type: application/json' \
                 -H 'Authorization: Bearer token123' \
                 https://api.example.com
            """)

        let headers = result!.headers.filter { !$0.key.isEmpty }
        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(headers[0].key, "Content-Type")
        XCTAssertEqual(headers[1].key, "Authorization")
        XCTAssertEqual(headers[1].value, "Bearer token123")
    }

    func testParsesLongFormHeader() {
        let result = CurlParser.parse("curl --header 'Accept: text/html' https://example.com")

        let headers = result!.headers.filter { !$0.key.isEmpty }
        XCTAssertEqual(headers[0].key, "Accept")
        XCTAssertEqual(headers[0].value, "text/html")
    }

    func testHeadersAlwaysHaveTrailingEmptyEntry() {
        let result = CurlParser.parse("curl -H 'Foo: bar' https://example.com")

        XCTAssertTrue(result!.headers.last!.key.isEmpty)
    }

    // MARK: - Request Body

    func testParsesDataFlag() {
        let result = CurlParser.parse(#"curl -d '{"name":"test"}' https://api.example.com"#)

        XCTAssertEqual(result?.body, #"{"name":"test"}"#)
        XCTAssertEqual(result?.method, .POST) // inferred from body
    }

    func testParsesLongFormData() {
        let result = CurlParser.parse(#"curl --data '{"key":"value"}' https://api.example.com"#)

        XCTAssertEqual(result?.body, #"{"key":"value"}"#)
    }

    func testParsesDataRaw() {
        let result = CurlParser.parse(#"curl --data-raw '{"raw":true}' https://api.example.com"#)

        XCTAssertEqual(result?.body, #"{"raw":true}"#)
    }

    func testParsesDataUrlencode() {
        let result = CurlParser.parse("curl --data-urlencode 'name=hello world' https://api.example.com")

        XCTAssertEqual(result?.body, "name=hello world")
    }

    func testBodyInfersPOSTWhenNoExplicitMethod() {
        let result = CurlParser.parse(#"curl -d '{"a":1}' https://api.example.com"#)

        XCTAssertEqual(result?.method, .POST)
    }

    func testExplicitMethodOverridesBodyInference() {
        let result = CurlParser.parse(#"curl -X PUT -d '{"a":1}' https://api.example.com"#)

        XCTAssertEqual(result?.method, .PUT)
    }

    // MARK: - Basic Auth

    func testParsesBasicAuth() {
        let result = CurlParser.parse("curl -u user:pass https://api.example.com")

        let headers = result!.headers.filter { !$0.key.isEmpty }
        XCTAssertEqual(headers.count, 1)
        XCTAssertEqual(headers[0].key, "Authorization")

        let expectedEncoded = Data("user:pass".utf8).base64EncodedString()
        XCTAssertEqual(headers[0].value, "Basic \(expectedEncoded)")
    }

    func testParsesLongFormUser() {
        let result = CurlParser.parse("curl --user admin:secret https://api.example.com")

        let headers = result!.headers.filter { !$0.key.isEmpty }
        XCTAssertEqual(headers[0].key, "Authorization")
    }

    // MARK: - URL Extraction

    func testParsesURLWithExplicitFlag() {
        let result = CurlParser.parse("curl --url https://api.example.com/data")

        XCTAssertEqual(result?.url, "https://api.example.com/data")
    }

    func testParsesHTTPUrl() {
        let result = CurlParser.parse("curl http://localhost:8080/api")

        XCTAssertEqual(result?.url, "http://localhost:8080/api")
    }

    func testURLCanAppearAnywhere() {
        let result = CurlParser.parse(#"curl -X POST -H 'Content-Type: application/json' https://api.example.com -d '{}'"#)

        XCTAssertEqual(result?.url, "https://api.example.com")
        XCTAssertEqual(result?.method, .POST)
        XCTAssertEqual(result?.body, "{}")
    }

    // MARK: - Ignored Flags

    func testIgnoresCommonFlags() {
        let result = CurlParser.parse("curl -k -L -s -S -v -i --compressed --insecure --location --silent --show-error --verbose --include https://example.com")

        XCTAssertEqual(result?.url, "https://example.com")
    }

    // MARK: - Quoting & Escaping

    func testHandlesDoubleQuotedStrings() {
        let result = CurlParser.parse(#"curl -H "Content-Type: application/json" https://example.com"#)

        let headers = result!.headers.filter { !$0.key.isEmpty }
        XCTAssertEqual(headers[0].key, "Content-Type")
        XCTAssertEqual(headers[0].value, "application/json")
    }

    func testHandlesLineContinuations() {
        let result = CurlParser.parse("curl \\\n  -X POST \\\n  https://api.example.com \\\n  -d '{\"a\":1}'")

        XCTAssertEqual(result?.method, .POST)
        XCTAssertEqual(result?.url, "https://api.example.com")
        XCTAssertEqual(result?.body, #"{"a":1}"#)
    }

    // MARK: - Case Insensitivity

    func testCurlCommandIsCaseInsensitive() {
        let result = CurlParser.parse("CURL https://example.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.url, "https://example.com")
    }

    // MARK: - Complex Real-World Examples

    func testParsesFullPostRequest() {
        let curl = """
            curl -X POST https://api.example.com/users \
              -H 'Content-Type: application/json' \
              -H 'Authorization: Bearer abc123' \
              -d '{"name":"John","email":"john@example.com"}'
            """
        let result = CurlParser.parse(curl)

        XCTAssertEqual(result?.url, "https://api.example.com/users")
        XCTAssertEqual(result?.method, .POST)
        XCTAssertEqual(result?.body, #"{"name":"John","email":"john@example.com"}"#)

        let headers = result!.headers.filter { !$0.key.isEmpty }
        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(headers[0].key, "Content-Type")
        XCTAssertEqual(headers[1].key, "Authorization")
    }
}
