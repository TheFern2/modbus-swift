// SPDX-License-Identifier: Apache-2.0

@testable import ModbusKit
import Testing

@Suite("ModbusServerConfiguration")
struct ServerConfigurationTests {

    @Test("Default configuration values")
    func defaults() {
        let config = ModbusServerConfiguration()

        #expect(config.host == "0.0.0.0")
        #expect(config.port == 502)
        #expect(config.maxConnections == 10)
        #expect(config.connectionIdleTimeout == .seconds(60))
    }

    @Test("Custom configuration values")
    func custom() {
        let config = ModbusServerConfiguration(
            host: "127.0.0.1",
            port: 5020,
            maxConnections: 50,
            connectionIdleTimeout: .seconds(120)
        )

        #expect(config.host == "127.0.0.1")
        #expect(config.port == 5020)
        #expect(config.maxConnections == 50)
        #expect(config.connectionIdleTimeout == .seconds(120))
    }

    @Test("Nil idle timeout disables timeout")
    func nilIdleTimeout() {
        let config = ModbusServerConfiguration(connectionIdleTimeout: nil)

        #expect(config.connectionIdleTimeout == nil)
    }

    @Test("Configuration is Equatable")
    func equatable() {
        let a = ModbusServerConfiguration(port: 5020)
        let b = ModbusServerConfiguration(port: 5020)

        #expect(a == b)
    }
}
