// SPDX-License-Identifier: Apache-2.0

import ModbusCore

// MARK: - ModbusServerError

/// Errors from server data store operations.
///
/// Each case maps to a Modbus exception code for the response.
public enum ModbusServerError: Error, Equatable, Sendable {
    /// Function code not supported (exception 0x01)
    case illegalFunction
    /// Address out of range (exception 0x02)
    case illegalDataAddress
    /// Invalid value (exception 0x03)
    case illegalDataValue
    /// Internal device failure (exception 0x04)
    case slaveDeviceFailure

    /// Maps to the corresponding Modbus exception for wire responses.
    public var modbusException: ModbusException {
        switch self {
        case .illegalFunction: .illegalFunction
        case .illegalDataAddress: .illegalDataAddress
        case .illegalDataValue: .illegalDataValue
        case .slaveDeviceFailure: .slaveDeviceFailure
        }
    }
}
