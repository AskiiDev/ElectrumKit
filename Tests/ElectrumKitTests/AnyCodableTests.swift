import XCTest
@testable import ElectrumKit

/// `AnyCodable` is the heterogeneous JSON value model underlying every request, response
/// and notification. Its decode path is what determines whether a Frigate by-name
/// notification surfaces as a `[String: Any]` (routable) or is lost.
final class AnyCodableTests: XCTestCase {

    private func decode(_ json: String) throws -> Any {
        try JSONDecoder().decode(AnyCodable.self, from: Data(json.utf8)).value
    }

    private func encode(_ value: Any) throws -> String {
        String(data: try JSONEncoder().encode(AnyCodable(value)), encoding: .utf8)!
    }

    func testDecodePrimitives() throws {
        XCTAssertEqual(try decode("42") as? Int, 42)
        XCTAssertEqual(try decode("3.5") as? Double, 3.5)
        XCTAssertEqual(try decode("\"hello\"") as? String, "hello")
        XCTAssertEqual(try decode("true") as? Bool, true)
        XCTAssertTrue(try decode("null") is NSNull)
    }

    func testIntDecodesAsIntNotDouble() throws {
        // Integers must decode as Int (Int-first), so JSON-RPC ids round-trip exactly.
        XCTAssertTrue(try decode("5000") is Int)
        XCTAssertFalse(try decode("5000") is Double)
    }

    func testDecodeArrayRecursivelyUnwraps() throws {
        let value = try decode("[1, \"a\", true, [2]]")
        let array = try XCTUnwrap(value as? [Any])
        XCTAssertEqual(array.count, 4)
        XCTAssertEqual(array[0] as? Int, 1)
        XCTAssertEqual(array[1] as? String, "a")
        XCTAssertEqual(array[2] as? Bool, true)
        XCTAssertEqual((array[3] as? [Any])?.first as? Int, 2)
    }

    func testDecodeObjectRecursivelyUnwraps() throws {
        // The Frigate-critical case: a JSON object decodes to [String: Any], not [Any].
        let value = try decode("{\"progress\": 1.0, \"history\": [{\"height\": 0}]}")
        let object = try XCTUnwrap(value as? [String: Any])
        // Foundation coerces a JSON `1.0` to Int; read numerics via NSNumber.
        XCTAssertEqual((object["progress"] as? NSNumber)?.doubleValue, 1.0)
        let history = try XCTUnwrap(object["history"] as? [Any])
        XCTAssertEqual((history.first as? [String: Any])?["height"] as? Int, 0)
    }

    func testRoundTripObject() throws {
        let original: [String: Any] = ["a": 1, "b": "x", "c": [true, 2]]
        let reDecoded = try XCTUnwrap(try decode(encode(original)) as? [String: Any])
        XCTAssertEqual(reDecoded["a"] as? Int, 1)
        XCTAssertEqual(reDecoded["b"] as? String, "x")
        XCTAssertEqual((reDecoded["c"] as? [Any])?.count, 2)
    }
}
