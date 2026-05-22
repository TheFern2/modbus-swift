// SPDX-License-Identifier: Apache-2.0

// MARK: - ModbusRTUServerConfiguration

/// Configuration for a Modbus RTU server.
public struct ModbusRTUServerConfiguration: Sendable, Equatable {
    // MARK: Lifecycle

    /// Creates an RTU server configuration.
    ///
    /// - Parameters:
    ///   - serialConfiguration: Serial port configuration
    ///   - unitIds: Set of unit IDs this server responds to (default: [1])
    public init(
        serialConfiguration: SerialConfiguration,
        unitIds: Set<UInt8> = [1],
    ) {
        self.serialConfiguration = serialConfiguration
        self.unitIds = unitIds
    }

    // MARK: Public

    /// Serial port configuration.
    public let serialConfiguration: SerialConfiguration

    /// Unit IDs this server responds to.
    public let unitIds: Set<UInt8>
}
