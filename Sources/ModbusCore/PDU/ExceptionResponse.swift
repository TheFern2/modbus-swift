// SPDX-License-Identifier: Apache-2.0

// MARK: - Exception Response Builder

/// Builds a Modbus exception response PDU (server-side).
///
/// Exception PDU format (2 bytes):
/// ```
/// [0] Function Code | 0x80
/// [1] Exception Code
/// ```
@inlinable
public func buildExceptionResponsePDU(
    functionCode: UInt8,
    exception: ModbusException,
) -> [UInt8] {
    [functionCode | ModbusFunctionCode.exceptionFlag, exception.rawValue]
}
