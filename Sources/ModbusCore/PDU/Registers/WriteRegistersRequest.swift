// SPDX-License-Identifier: Apache-2.0

// MARK: - WriteSingleRegisterRequestPDU

/// Parsed Write Single Register request (FC 0x06, server-side parsing).
public struct WriteSingleRegisterRequestPDU: Equatable, Sendable {
    @usableFromInline
    init(address: UInt16, value: UInt16) {
        self.address = address
        self.value = value
    }

    /// Register address
    public let address: UInt16
    /// Value to write
    public let value: UInt16
}

// MARK: - WriteMultipleRegistersRequestPDU

/// Parsed Write Multiple Registers request (FC 0x10, server-side parsing).
public struct WriteMultipleRegistersRequestPDU: Equatable, Sendable {
    @usableFromInline
    init(address: UInt16, values: [UInt16]) {
        self.address = address
        self.values = values
    }

    /// Starting register address
    public let address: UInt16
    /// Values to write
    public let values: [UInt16]
}

// MARK: - Write Single Register Request Parser

/// Parses a Write Single Register request PDU (FC 0x06).
///
/// Request PDU format (5 bytes, Big Endian):
/// ```
/// [0]   Function Code (0x06)
/// [1-2] Register Address
/// [3-4] Register Value
/// ```
@inlinable
public func parseWriteSingleRegisterRequestPDU(
    _ pdu: Span<UInt8>,
) throws(PDUError) -> WriteSingleRegisterRequestPDU {
    guard pdu.count >= PDUSize.writeSingleRegister else {
        throw .pduTooShort
    }

    guard
        let address = readUInt16BE(pdu, at: 1),
        let value = readUInt16BE(pdu, at: 3) else
    {
        throw .pduTooShort
    }

    return WriteSingleRegisterRequestPDU(address: address, value: value)
}

/// Convenience overload for Array input.
@inlinable
public func parseWriteSingleRegisterRequestPDU(
    _ pdu: [UInt8],
) throws(PDUError) -> WriteSingleRegisterRequestPDU {
    try parseWriteSingleRegisterRequestPDU(pdu.span)
}

// MARK: - Write Multiple Registers Request Parser

/// Parses a Write Multiple Registers request PDU (FC 0x10).
///
/// Request PDU format (6 + N bytes, Big Endian):
/// ```
/// [0]   Function Code (0x10)
/// [1-2] Starting Address
/// [3-4] Quantity of Registers
/// [5]   Byte Count (N = Quantity x 2)
/// [6..] Register Values (N bytes, Big Endian per register)
/// ```
@inlinable
public func parseWriteMultipleRegistersRequestPDU(
    _ pdu: Span<UInt8>,
) throws(PDUError) -> WriteMultipleRegistersRequestPDU {
    guard pdu.count >= PDUSize.writeMultipleRegistersRequestHeader else {
        throw .pduTooShort
    }

    guard
        let address = readUInt16BE(pdu, at: 1),
        let quantity = readUInt16BE(pdu, at: 3) else
    {
        throw .pduTooShort
    }

    let byteCount = pdu[5]

    guard byteCount == UInt8(quantity * 2) else {
        throw .byteCountMismatch(expected: UInt8(quantity * 2), got: byteCount)
    }

    let expectedSize = PDUSize.writeMultipleRegistersRequestHeader + Int(byteCount)
    guard pdu.count >= expectedSize else {
        throw .pduTooShort
    }

    var values = [UInt16]()
    values.reserveCapacity(Int(quantity))

    for i in 0 ..< Int(quantity) {
        let offset = 6 + (i * 2)
        guard let value = readUInt16BE(pdu, at: offset) else {
            throw .pduTooShort
        }
        values.append(value)
    }

    return WriteMultipleRegistersRequestPDU(address: address, values: values)
}

/// Convenience overload for Array input.
@inlinable
public func parseWriteMultipleRegistersRequestPDU(
    _ pdu: [UInt8],
) throws(PDUError) -> WriteMultipleRegistersRequestPDU {
    try parseWriteMultipleRegistersRequestPDU(pdu.span)
}
