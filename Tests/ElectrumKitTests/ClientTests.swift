import XCTest
@testable import ElectrumKit

/// Public-surface + configuration tests. (Connection, TLS, and live notification routing require
/// a server and are exercised by the integration tests against a real Electrum / Frigate endpoint)
final class ClientTests: XCTestCase {

    func testConfigDefaults() {
        let config = ElectrumConfig()
        XCTAssertEqual(config.pingInterval, 30.0)
        XCTAssertEqual(config.requestLimit, 100)
        XCTAssertEqual(config.requestTimeout, 30.0)
        XCTAssertEqual(config.packetMinSize, 1024)
        XCTAssertEqual(config.reconnectMaxDelay, 60.0)
        XCTAssertEqual(config.reconnectMultiplier, 2.0)
    }

    func testErrorEquatable() {
        XCTAssertEqual(ElectrumError.connectionClosed, .connectionClosed)
        XCTAssertEqual(ElectrumError.requestTimeout, .requestTimeout)
        XCTAssertEqual(
            ElectrumError.responseError(code: 1, message: "a"),
            ElectrumError.responseError(code: 1, message: "a")
        )
        XCTAssertNotEqual(
            ElectrumError.responseError(code: 1, message: "a"),
            ElectrumError.responseError(code: 2, message: "a")
        )
        XCTAssertNotEqual(ElectrumError.connectionClosed, .requestTimeout)
    }

    func testConnectionStateBeforeStartIsDisconnected() {
        let client = ElectrumClient(host: "example.invalid", port: 50002)
        XCTAssertEqual(client.connectionState, .disconnected)
    }

    func testClientIsSendable() {
        // Compile-time assertion that ElectrumClient can cross concurrency domains.
        func requiresSendable<T: Sendable>(_ value: T) {}
        requiresSendable(ElectrumClient(host: "example.invalid", port: 50002))
    }
}
