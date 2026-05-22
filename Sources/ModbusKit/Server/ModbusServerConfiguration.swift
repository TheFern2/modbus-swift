// SPDX-License-Identifier: Apache-2.0

// MARK: - ModbusServerConfiguration

/// Configuration for Modbus TCP server.
public struct ModbusServerConfiguration: Sendable, Equatable {

    /// Creates a server configuration.
    ///
    /// - Parameters:
    ///   - host: Bind address (default: "0.0.0.0")
    ///   - port: Listen port (default: 502)
    ///   - maxConnections: Maximum concurrent client connections (default: 10)
    ///   - connectionIdleTimeout: Idle timeout per connection, nil to disable (default: 60s)
    public init(
        host: String = "0.0.0.0",
        port: Int = MBAPConstants.defaultPort,
        maxConnections: Int = 10,
        connectionIdleTimeout: Duration? = .seconds(60)
    ) {
        self.host = host
        self.port = port
        self.maxConnections = maxConnections
        self.connectionIdleTimeout = connectionIdleTimeout
    }

    /// Bind address
    public let host: String

    /// Listen port (default: 502)
    public let port: Int

    /// Maximum concurrent client connections
    public let maxConnections: Int

    /// Idle timeout per connection (nil to disable)
    public let connectionIdleTimeout: Duration?
}
