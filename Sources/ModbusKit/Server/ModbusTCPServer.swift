// SPDX-License-Identifier: Apache-2.0

import Logging
import ModbusCore
import NIOCore
import NIOPosix
import ServiceLifecycle
import Synchronization

// MARK: - ModbusTCPServer

/// Modbus TCP server using SwiftNIO.
///
/// Listens for incoming Modbus TCP connections and dispatches requests
/// to a `ModbusDataStore`. Conforms to `Service` for ServiceLifecycle
/// integration with graceful shutdown.
///
/// ## Usage
///
/// ```swift
/// let store = InMemoryDataStore(unitIds: [1])
/// let server = ModbusTCPServer(
///     configuration: ModbusServerConfiguration(port: 5020),
///     dataStore: store
/// )
///
/// // Standalone
/// try await server.run()
///
/// // With ServiceLifecycle
/// let group = ServiceGroup(
///     services: [server],
///     gracefulShutdownSignals: [.sigterm, .sigint],
///     logger: logger
/// )
/// try await group.run()
/// ```
public final class ModbusTCPServer: Sendable {

    /// Server configuration.
    public let configuration: ModbusServerConfiguration

    private let dataStore: any ModbusDataStore
    private let logger: Logger?
    private let metrics: ModbusMetrics?
    private let eventLoopGroup: EventLoopGroup
    private let _connectionCount: Mutex<Int>

    /// Creates a Modbus TCP server.
    ///
    /// - Parameters:
    ///   - configuration: Server configuration
    ///   - dataStore: Data store for register/coil values
    ///   - logger: Optional logger (default: nil)
    ///   - metrics: Optional metrics (default: nil)
    public init(
        configuration: ModbusServerConfiguration = ModbusServerConfiguration(),
        dataStore: any ModbusDataStore,
        logger: Logger? = nil,
        metrics: ModbusMetrics? = nil
    ) {
        self.configuration = configuration
        self.dataStore = dataStore
        self.logger = logger
        self.metrics = metrics
        self.eventLoopGroup = MultiThreadedEventLoopGroup.singleton
        self._connectionCount = Mutex(0)
    }

    /// The number of currently connected clients.
    public var connectionCount: Int {
        _connectionCount.withLock { $0 }
    }
}

// MARK: - Service

extension ModbusTCPServer: Service {

    /// Runs the server, accepting connections until graceful shutdown.
    public func run() async throws {
        let server = self

        let serverChannel = try await ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                let maxConns = server.configuration.maxConnections

                let current = server._connectionCount.withLock { count -> Int in
                    count += 1
                    return count
                }

                if current > maxConns {
                    server._connectionCount.withLock { $0 -= 1 }
                    server.logger?.warning("Connection limit reached (\(maxConns)), rejecting client")
                    return channel.close()
                }

                server.logger?.debug("Client connected (\(current)/\(maxConns))")

                channel.closeFuture.whenComplete { _ in
                    let remaining = server._connectionCount.withLock { count -> Int in
                        count -= 1
                        return count
                    }
                    server.logger?.debug("Client disconnected (\(remaining)/\(maxConns))")
                }

                return channel.pipeline.addHandlers([
                    ByteToMessageHandler(ModbusFrameDecoder()),
                    ModbusServerHandler(dataStore: server.dataStore, logger: server.logger),
                ])
            }
            .bind(host: configuration.host, port: configuration.port)
            .get()

        logger?.info("Modbus TCP server listening on \(configuration.host):\(configuration.port)")

        // Wait for graceful shutdown signal
        try await gracefulShutdown()

        logger?.info("Shutting down Modbus TCP server")
        try await serverChannel.close()
    }
}
