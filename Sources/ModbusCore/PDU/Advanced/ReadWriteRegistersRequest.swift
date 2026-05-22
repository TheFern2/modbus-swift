// SPDX-License-Identifier: Apache-2.0

// MARK: - ReadWriteMultipleRegistersRequestPDU

/// Parsed Read/Write Multiple Registers request (FC 0x17, server-side parsing).
public struct ReadWriteMultipleRegistersRequestPDU: Equatable, Sendable {
    @usableFromInline
    init(readAddress: UInt16, readCount: UInt16, writeAddress: UInt16, writeValues: [UInt16]) {
        self.readAddress = readAddress
        self.readCount = readCount
        self.writeAddress = writeAddress
        self.writeValues = writeValues
    }

    /// Starting address for read operation
    public let readAddress: UInt16
    /// Number of registers to read
    public let readCount: UInt16
    /// Starting address for write operation
    public let writeAddress: UInt16
    /// Values to write
    public let writeValues: [UInt16]
}

// MARK: - Read/Write Multiple Registers Request Parser

/// Parses a Read/Write Multiple Registers request PDU (FC 0x17).
///
/// Request PDU format (10 + N bytes, Big Endian):
/// ```
/// [0]     Function Code (0x17)
/// [1-2]   Read Starting Address
/// [3-4]   Quantity to Read
/// [5-6]   Write Starting Address
/// [7-8]   Quantity to Write
/// [9]     Write Byte Count (N = Quantity x 2)
/// [10..]  Write Values (N bytes, Big Endian per register)
/// ```
@inlinable
public func parseReadWriteMultipleRegistersRequestPDU(
    _ pdu: Span<UInt8>,
) throws(PDUError) -> ReadWriteMultipleRegistersRequestPDU {
    guard pdu.count >= 10 else {
        throw .pduTooShort
    }

    guard
        let readAddress = readUInt16BE(pdu, at: 1),
        let readCount = readUInt16BE(pdu, at: 3),
        let writeAddress = readUInt16BE(pdu, at: 5),
        let writeQuantity = readUInt16BE(pdu, at: 7) else
    {
        throw .pduTooShort
    }

    let writeByteCount = pdu[9]

    guard writeByteCount == UInt8(writeQuantity * 2) else {
        throw .byteCountMismatch(expected: UInt8(writeQuantity * 2), got: writeByteCount)
    }

    let expectedSize = 10 + Int(writeByteCount)
    guard pdu.count >= expectedSize else {
        throw .pduTooShort
    }

    var writeValues = [UInt16]()
    writeValues.reserveCapacity(Int(writeQuantity))

    for i in 0 ..< Int(writeQuantity) {
        let offset = 10 + (i * 2)
        guard let value = readUInt16BE(pdu, at: offset) else {
            throw .pduTooShort
        }
        writeValues.append(value)
    }

    return ReadWriteMultipleRegistersRequestPDU(
        readAddress: readAddress,
        readCount: readCount,
        writeAddress: writeAddress,
        writeValues: writeValues,
    )
}

/// Convenience overload for Array input.
@inlinable
public func parseReadWriteMultipleRegistersRequestPDU(
    _ pdu: [UInt8],
) throws(PDUError) -> ReadWriteMultipleRegistersRequestPDU {
    try parseReadWriteMultipleRegistersRequestPDU(pdu.span)
}

// MARK: - Read/Write Multiple Registers Response Builder

/// Builds a Read/Write Multiple Registers response PDU (FC 0x17, server-side).
///
/// Response PDU format:
/// ```
/// [0]   Function Code (0x17)
/// [1]   Byte Count (N = count x 2)
/// [2..] Read Register Data (N bytes, Big Endian per register)
/// ```
@inlinable
public func buildReadWriteMultipleRegistersResponsePDU(
    registers: [UInt16],
) -> [UInt8] {
    buildReadRegistersResponsePDU(
        functionCode: ModbusFunctionCode.readWriteMultipleRegisters,
        registers: registers,
    )
}
