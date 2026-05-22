// SPDX-License-Identifier: Apache-2.0

// MARK: - WriteSingleCoilRequestPDU

/// Parsed Write Single Coil request (FC 0x05, server-side parsing).
public struct WriteSingleCoilRequestPDU: Equatable, Sendable {
    @usableFromInline
    init(address: UInt16, value: Bool) {
        self.address = address
        self.value = value
    }

    /// Coil address
    public let address: UInt16
    /// Value to write
    public let value: Bool
}

// MARK: - WriteMultipleCoilsRequestPDU

/// Parsed Write Multiple Coils request (FC 0x0F, server-side parsing).
public struct WriteMultipleCoilsRequestPDU: Equatable, Sendable {
    @usableFromInline
    init(address: UInt16, values: [Bool]) {
        self.address = address
        self.values = values
    }

    /// Starting coil address
    public let address: UInt16
    /// Coil values to write
    public let values: [Bool]
}

// MARK: - Write Single Coil Request Parser

/// Parses a Write Single Coil request PDU (FC 0x05).
///
/// Request PDU format (5 bytes, Big Endian):
/// ```
/// [0]   Function Code (0x05)
/// [1-2] Output Address
/// [3-4] Output Value (0xFF00=ON, 0x0000=OFF)
/// ```
@inlinable
public func parseWriteSingleCoilRequestPDU(
    _ pdu: Span<UInt8>,
) throws(PDUError) -> WriteSingleCoilRequestPDU {
    guard pdu.count >= PDUSize.writeSingleRegister else {
        throw .pduTooShort
    }

    guard
        let address = readUInt16BE(pdu, at: 1),
        let rawValue = readUInt16BE(pdu, at: 3) else
    {
        throw .pduTooShort
    }

    guard rawValue == CoilOn || rawValue == CoilOff else {
        throw .illegalCoilValue(rawValue)
    }

    return WriteSingleCoilRequestPDU(address: address, value: rawValue == CoilOn)
}

/// Convenience overload for Array input.
@inlinable
public func parseWriteSingleCoilRequestPDU(
    _ pdu: [UInt8],
) throws(PDUError) -> WriteSingleCoilRequestPDU {
    try parseWriteSingleCoilRequestPDU(pdu.span)
}

// MARK: - Write Multiple Coils Request Parser

/// Parses a Write Multiple Coils request PDU (FC 0x0F).
///
/// Request PDU format (6 + N bytes, Big Endian):
/// ```
/// [0]   Function Code (0x0F)
/// [1-2] Starting Address
/// [3-4] Quantity of Outputs (1-1968)
/// [5]   Byte Count (N = ceil(quantity/8))
/// [6..] Output Values (N bytes, LSB first per byte)
/// ```
@inlinable
public func parseWriteMultipleCoilsRequestPDU(
    _ pdu: Span<UInt8>,
) throws(PDUError) -> WriteMultipleCoilsRequestPDU {
    guard pdu.count >= 6 else {
        throw .pduTooShort
    }

    guard
        let address = readUInt16BE(pdu, at: 1),
        let quantity = readUInt16BE(pdu, at: 3) else
    {
        throw .pduTooShort
    }

    let byteCount = pdu[5]
    let expectedByteCount = UInt8((quantity + 7) / 8)

    guard byteCount == expectedByteCount else {
        throw .byteCountMismatch(expected: expectedByteCount, got: byteCount)
    }

    let expectedSize = 6 + Int(byteCount)
    guard pdu.count >= expectedSize else {
        throw .pduTooShort
    }

    var values = [Bool]()
    values.reserveCapacity(Int(quantity))

    for i in 0 ..< Int(quantity) {
        let byteIndex = 6 + (i / 8)
        let bitIndex = i % 8
        guard let byte = readUInt8(pdu, at: byteIndex) else {
            throw .pduTooShort
        }
        values.append((byte >> bitIndex) & 0x01 != 0)
    }

    return WriteMultipleCoilsRequestPDU(address: address, values: values)
}

/// Convenience overload for Array input.
@inlinable
public func parseWriteMultipleCoilsRequestPDU(
    _ pdu: [UInt8],
) throws(PDUError) -> WriteMultipleCoilsRequestPDU {
    try parseWriteMultipleCoilsRequestPDU(pdu.span)
}
